// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IActivationRouter } from "./interfaces/IActivationRouter.sol";
import { ICryptoOctoRarityRegistry } from "./interfaces/ICryptoOctoRarityRegistry.sol";
import { IActivationManager } from "./interfaces/IActivationManager.sol";

/// @title ActivationManager
/// @author 3Blocks
/// @notice Manages locking and unlocking of NFTs for cross-chain activation
/// @dev
/// - Locks NFTs on the source chain
/// - Sends activation messages to a LayerZero-based router
/// - Unlocks NFTs when the router confirms deactivation from the destination chain
///
/// Users interact via `activateToken`. The router interacts via `deactivateToken`.
contract ActivationManager is Ownable, IActivationManager {
    using OptionsBuilder for bytes;

    uint8 public constant MIN_RARITY = 3;

    // =============================================================
    // State Variables
    // =============================================================

    /// @notice Address of the router contract responsible for cross-chain messaging
    address public router;

    /// @notice ERC721 token that can be locked
    IERC721 public token;

    /// @notice Mapping of user address to locked token information
    mapping(address => TokenInfo) public locks;

    // =============================================================
    // Constructor
    // =============================================================

    /// @notice Initializes the ActivationManager with token and router addresses
    /// @param _owner The owner of the contract (can configure router)
    /// @param _token The ERC721 token contract to be locked
    /// @param _router The router contract responsible for sending activation messages
    constructor(address _owner, address _token, address _router) Ownable(_owner) {
        token = IERC721(_token);
        router = _router;
    }

    // =============================================================
    // Fallback Functions
    // =============================================================

    /// @notice Allows the contract to receive native ETH for LayerZero fees
    receive() external payable {}

    /// @notice Fallback function to accept ETH and unknown calls
    fallback() external payable {}

    // =============================================================
    // Owner Withdraw
    // =============================================================

    /// @notice Withdraws all native coins from the contract
    /// @dev Only callable by the owner
    function withdrawNative() external onlyOwner {
        uint256 balance = address(this).balance;

        if (balance == 0) {
            revert NoFundsToWithdraw();
        }

        (bool success, ) = payable(owner()).call{ value: balance }("");
        if (!success) {
            revert WithdrawFailed();
        }

        emit NativeWithdrawn(owner(), balance);
    }

    // =============================================================
    // Core Activation Logic
    // =============================================================

    /// @notice Locks the caller's NFT and sends activation info to the router
    /// @dev
    /// Requirements:
    /// - Caller must own the NFT
    /// - NFT rarity must be Gold or Diamond (rarity >= 3)
    /// - Contract must have enough ETH to pay cross-chain fees
    ///
    /// Effects:
    /// - Transfers NFT from caller to this contract
    /// - Stores tokenId and rarity in `locks` mapping
    /// - Encodes and sends activation payload to router via LayerZero
    ///
    /// @param tokenId The ID of the NFT to activate
    function activateToken(uint256 tokenId, uint128 customGasLimit) external {
        if (token.ownerOf(tokenId) != msg.sender) {
            revert NotOwnerOfToken();
        }

        token.transferFrom(msg.sender, address(this), tokenId);

        // Retrieve NFT rarity from the registry
        uint8 rarity = uint8(ICryptoOctoRarityRegistry(address(token)).getRarity(tokenId));

        if (rarity < MIN_RARITY) {
            revert RarityNotGoldOrDiamond();
        }

        // Store locked token info
        locks[msg.sender] = TokenInfo(tokenId, rarity);

        // Encode payload for cross-chain messaging
        bytes memory payload = abi.encode(msg.sender, tokenId, rarity);

        // Set default options for LayerZero messaging
        bytes memory extraOptions = customGasLimit > 0
            ? OptionsBuilder.newOptions().addExecutorLzReceiveOption(customGasLimit, 0)
            : new bytes(0);

        // Query router for required fee
        uint256 fee = IActivationRouter(router).quoteSend(payload, extraOptions);

        if (address(this).balance < fee) {
            revert OutOfFunds();
        }

        // Send activation message to destination chain
        IActivationRouter(router).sendTokenActivation{ value: fee }(payload, extraOptions);
    }

    /// @notice Unlocks a previously locked NFT and returns it to the user
    /// @dev Only callable by the router after receiving a valid deactivation message
    ///
    /// Effects:
    /// - Transfers NFT back to the user
    /// - Deletes the entry in `locks` mapping
    ///
    /// @param user The address of the NFT owner to return the token to
    /// @param tokenId The ID of the NFT to deactivate/unlock
    function deactivateToken(address user, uint256 tokenId) external {
        if (msg.sender != router) {
            revert NotAllowed();
        }

        token.transferFrom(address(this), user, tokenId);

        delete locks[user];
    }
}
