// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IFeeReduction } from "./IFeeReduction.sol";

/**
 * @title IStrategyBuilderFeeReduction
 * @author 3Blocks
 * @notice Interface for cross-chain fee reduction via StrategyBuilder.
 *
 * Provides unified fee reduction based on:
 * 1. Tiered token locking (via ITieredTokenLocker)
 * 2. NFT rarity activation (via cross-chain router deposit)
 *
 * Designed for use with LayerZero-enabled activation systems.
 */
interface IStrategyBuilderFeeReduction is IFeeReduction {
    // ──────────────────────────────────────────────────────────────
    // Errors
    // ──────────────────────────────────────────────────────────────

    /// @notice User already has an active deposited token
    error AlreadyTokenActive();

    /// @notice User has no active token deposited
    error NoTokenActive();

    /// @notice Caller is not allowed (router-only)
    error NotAllowed();

    /// @notice Contract has insufficient native funds to send cross-chain message
    error OutOfFunds();

    /// @notice Thrown when the owner tries to set an invalid gas limit
    error GasLimitTooLow();

    /// @notice Thrown when trying to withdraw with zero balance
    error NoFundsToWithdraw();

    /// @notice Thrown when native transfer fails
    error WithdrawFailed();

    // ──────────────────────────────────────────────────────────────
    // Structs
    // ──────────────────────────────────────────────────────────────

    /**
     * @notice Stores information about a deposited NFT for a user
     * @param tokenId The deposited NFT tokenId
     * @param rarity  The rarity classification of the NFT
     */
    struct TokenInfo {
        uint256 tokenId;
        uint8 rarity;
    }

    // ──────────────────────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────────────────────

    /// @notice Emitted when the owner withdraws native funds
    event NativeWithdrawn(address indexed owner, uint256 amount);

    /**
     * @notice Emitted when a token is deposited for a user
     * @param account The user receiving activation
     * @param tokenId The deposited NFT tokenId
     * @param rarity  The rarity of the deposited NFT
     */
    event Deposit(address indexed account, uint256 indexed tokenId, uint8 rarity);

    /**
     * @notice Emitted when a user withdraws their deposited token
     * @param account The withdrawing user
     * @param tokenId The withdrawn tokenId
     */
    event Withdraw(address indexed account, uint256 indexed tokenId);

    // ──────────────────────────────────────────────────────────────
    // State Variables
    // ──────────────────────────────────────────────────────────────

    /// @notice Returns the TieredTokenLocker contract address
    function lock() external view returns (address);

    /// @notice Returns the router allowed to deposit tokens
    function router() external view returns (address);

    /**
     * @notice Returns the deposited token info for a given user
     * @param user The user address
     * @return tokenId The active deposited tokenId (0 if none)
     * @return rarity  The stored rarity value
     */
    function userTokenInfos(address user) external view returns (uint256 tokenId, uint8 rarity);

    // ──────────────────────────────────────────────────────────────
    // Execution Functions
    // ──────────────────────────────────────────────────────────────

    /// @notice Withdraws all native coins from the contract
    /// @dev Only callable by the owner
    function withdrawNative() external;

    /**
     * @notice Deposits a token activation for a user
     * @dev Router-only function, called when an NFT activation message arrives cross-chain
     * Requirements:
     * - Caller must be router
     * - User must not already have an active token
     * Emits {Deposit}
     * @param user    The user receiving the activation
     * @param tokenId The activated NFT tokenId
     * @param rarity  The rarity classification of the NFT
     */
    function activateTokenForUser(address user, uint256 tokenId, uint8 rarity) external;

    /**
     * @notice Withdraws the currently deposited NFT activation for the caller
     * Requirements:
     * - Caller must have an active token deposited
     * Emits {Withdraw}
     */
    function withdrawToken(uint128 customGasLimit) external;

    // ──────────────────────────────────────────────────────────────
    // Fee Reduction Logic
    // ──────────────────────────────────────────────────────────────

    /**
     * @notice Returns the fee reduction in basis points (bps) for a given wallet
     * @dev Fee reduction is defined as the maximum of:
     *  - Tier-based reduction
     *  - NFT rarity-based reduction
     * @param wallet The wallet or StrategyVault address
     * @return reduction Fee reduction in bps (0–10000)
     */
    function getFeeReduction(address wallet) external view returns (uint256 reduction);
}
