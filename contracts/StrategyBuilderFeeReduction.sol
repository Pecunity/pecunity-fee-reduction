// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IStrategyBuilderFeeReduction } from "./interfaces/IStrategyBuilderFeeReduction.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IStrategyVault } from "./interfaces/IStrategyVault.sol";
import { ITieredTokenLocker } from "../contracts/interfaces/ITieredTokenLocker.sol";
import { ICryptoOctoRarityRegistry } from "../contracts/interfaces/ICryptoOctoRarityRegistry.sol";
import { IStrategyBuilderFeeReductionRouter } from "./interfaces/IStrategyBuilderFeeReductionRouter.sol";
import { IStrategyVaultFactory } from "./interfaces/IStrategyVaultFactory.sol";

/**
 * @title FeeReduction
 * @author 3Blocks UG
 * @notice Provides a unified fee reduction mechanism based on:
 * 1) Token lock tiers
 * 2) Deposited NFT rarity
 *
 * @dev This contract resolves the effective user address in case the provided
 * wallet is a StrategyVault contract by:
 * - Checking ERC165 supportsInterface for IStrategyVault
 * - Resolving the underlying owner() if applicable
 *
 * The final fee reduction is defined as the maximum of:
 * - The reduction derived from the user's lock tier
 * - The reduction derived from the deposited NFT rarity
 *
 * Fee reductions are expressed in basis points (bps),
 * where 10_000 = 100%.
 *
 * This contract is designed to be read-only for fee logic,
 * except for explicit NFT deposit/withdrawal by users.
 */
contract StrategyBuilderFeeReduction is IStrategyBuilderFeeReduction {
    using OptionsBuilder for bytes;

    // ┏━━━━━━━━━━━━━━━━━┓
    // ┃    Constants    ┃
    // ┗━━━━━━━━━━━━━━━━━┛

    /// @notice Divisor for percentage calculations (10000 = 100%).
    uint256 public constant PERCENTAGE_DIVISOR = 10000;

    // ┏━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   State Variables    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Address of the Tiered Token Locker contract.
     * @dev Used to resolve the user's lock tier for fee reduction.
     */
    address public immutable lock;
    address public immutable router;
    address public immutable factory;

    bytes4 public strategyVaultInterfaceId = 0x3d6efa61;

    /**
     * @notice Mapping of user address to deposited NFT tokenId.
     * @dev Each user may deposit at most one NFT at a time.
     * A value of 0 indicates no NFT deposited.
     */
    mapping(address => TokenInfo) public userTokenInfos;

    // ┏━━━━━━━━━━━━━━━━━━━━━┓
    // ┃     Constructor     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━┛

    constructor(address _lock, address _router, address _factory) {
        lock = _lock;
        router = _router;
        factory = _factory;
    }

    receive() external payable {}

    fallback() external payable {}

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Execution Functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function activateTokenForUser(address user, uint256 tokenId, uint8 rarity) external {
        if (msg.sender != router) {
            revert NotAllowed();
        }

        if (userTokenInfos[user].tokenId != 0) {
            revert AlreadyTokenActive();
        }

        userTokenInfos[user] = TokenInfo(tokenId, rarity);

        emit Deposit(user, tokenId, rarity);
    }

    /**
     * @notice Withdraws the previously deposited token.
     * @dev Resets the user's deposited token state and transfers
     * the token back to the user.
     *
     * Requirements:
     * - The caller must have a token deposited.
     *
     * Emits a {Withdraw} event.
     */
    function withdrawToken(uint128 customGasLimit) external {
        TokenInfo memory tokenInfo = userTokenInfos[msg.sender];
        uint256 tokenId = tokenInfo.tokenId;

        if (tokenId == 0) {
            revert NoTokenActive();
        }

        userTokenInfos[msg.sender] = TokenInfo(0, 0);

        bytes memory payload = abi.encode(msg.sender, tokenId, tokenInfo.rarity);

        // Set default options for LayerZero messaging
        bytes memory extraOptions = customGasLimit > 0
            ? OptionsBuilder.newOptions().addExecutorLzReceiveOption(customGasLimit, 0)
            : new bytes(0);

        uint256 fee = IStrategyBuilderFeeReductionRouter(router).quoteSend(payload, extraOptions);

        if (address(this).balance < fee) {
            revert OutOfFunds();
        }

        IStrategyBuilderFeeReductionRouter(router).sendTokenDeactivation{ value: fee }(payload, extraOptions);

        emit Withdraw(msg.sender, tokenId);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   View Functions     ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Returns the effective fee reduction for a given wallet.
     * @dev If the wallet is a StrategyVault, the underlying owner
     * is resolved and used for fee calculation.
     *
     * The returned reduction is the maximum of:
     * - Lock-tier based fee reduction
     * - NFT-rarity based fee reduction
     *
     * If neither applies, returns 0.
     *
     * @param wallet The wallet or StrategyVault address to query.
     * @return reduction The fee reduction in basis points (bps).
     */
    function getFeeReduction(address wallet) external view override returns (uint256) {
        address user = _resolveVaultOwner(wallet);

        // ─────────────────────────────
        // 1️⃣ Lock-Tier
        // ─────────────────────────────
        (, , ITieredTokenLocker.Tier lockTier, ) = ITieredTokenLocker(lock).getLockInfo(user);
        uint256 lockReduction = _tierToFeeReduction(lockTier);

        // ─────────────────────────────
        // 2️⃣ NFT-Rarity
        // ─────────────────────────────
        uint256 nftReduction = 0;
        TokenInfo memory tokenInfo = userTokenInfos[user];
        uint256 tokenId = tokenInfo.tokenId;
        if (tokenId != 0) {
            nftReduction = _rarityToFeeReduction(ICryptoOctoRarityRegistry.Rarity(tokenInfo.rarity));
        }

        // ─────────────────────────────
        // 3️⃣ Max von Lock & NFT
        // ─────────────────────────────
        uint256 maxReduction = lockReduction >= nftReduction ? lockReduction : nftReduction;
        return maxReduction;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Internal Functions   ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Maps a lock tier to a fee reduction in basis points.
     * @dev Returns 0 for Tier.None or unknown tiers.
     */
    function _tierToFeeReduction(ITieredTokenLocker.Tier tier) internal pure returns (uint256) {
        // Tier-based fee reductions in basis points
        if (tier == ITieredTokenLocker.Tier.Basic) return 500; // 5%
        if (tier == ITieredTokenLocker.Tier.Bronze) return 750; // 7.5%
        if (tier == ITieredTokenLocker.Tier.Silver) return 1000; // 10%
        if (tier == ITieredTokenLocker.Tier.Gold) return 1500; // 15%
        if (tier == ITieredTokenLocker.Tier.Diamond) return 2500; // 25%
        return 0; // Tier.None or unknown
    }

    /**
     * @notice Maps an NFT rarity to a fee reduction in basis points.
     * @dev Only Gold and Diamond rarities currently grant reductions.
     */
    function _rarityToFeeReduction(ICryptoOctoRarityRegistry.Rarity rarity) internal pure returns (uint256) {
        if (rarity == ICryptoOctoRarityRegistry.Rarity.Gold) return 5000; // 50%
        if (rarity == ICryptoOctoRarityRegistry.Rarity.Diamond) return 5000; // 50%
        return 0;
    }

    /**
     * @notice Resolves the effective user address for fee calculations.
     * @dev If the wallet is an EOA, it is returned directly.
     *
     * If the wallet is a contract, this function attempts to:
     * 1. Detect if it supports the IStrategyVault interface via ERC165.
     * 2. If so, attempt to resolve the underlying owner() address.
     *
     * If any step fails (revert, invalid return data, zero owner),
     * the original wallet address is used as a safe fallback.
     *
     * This ensures robustness against:
     * - Non-compliant contracts
     * - Malicious or reverting implementations
     * - Unexpected ABI behavior
     *
     * @param wallet The wallet or contract address to resolve.
     * @return resolved The resolved owner or original wallet address.
     */
    function _resolveVaultOwner(address wallet) public view returns (address) {
        // EOA
        if (wallet.code.length == 0) return wallet;

        // ─────────────────────────────
        // 1️⃣ Check if wallet is a deployed strategy vault
        // ─────────────────────────────
        bool isStrategyVault = IStrategyVaultFactory(factory).isDeployedVault(wallet);

        // No strategy vault
        if (!isStrategyVault) return wallet;

        // ─────────────────────────────
        // 2️⃣ Try owner()
        // ─────────────────────────────
        address owner = Ownable(wallet).owner();

        if (owner == address(0)) return wallet;

        return owner;
    }
}
