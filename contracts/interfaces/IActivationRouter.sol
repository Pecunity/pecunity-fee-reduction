// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @title IActivationRouter
/// @author 3Blocks
/// @notice Interface for a LayerZero-based router that handles cross-chain NFT activation messages.
/// @dev
/// The router is responsible for:
/// - Receiving activation payloads from the ActivationManager on the source chain
/// - Sending messages to the destination chain LayerZero endpoint
/// - Quoting message fees before sending
///
/// Only the ActivationManager is allowed to trigger `sendTokenActivation`.
interface IActivationRouter {
    // =============================================================
    // Errors
    // =============================================================

    /// @notice Thrown when a restricted function is called by an unauthorized address
    error NotAllowed();

    /// @notice Thrown when trying to withdraw with zero balance
    error NoFundsToWithdraw();

    /// @notice Thrown when native transfer fails
    error WithdrawFailed();

    // =============================================================
    // Events
    // =============================================================

    /// @notice Emitted when the owner withdraws native funds
    event NativeWithdrawn(address indexed owner, uint256 amount);

    // =============================================================
    // Owner Withdraw
    // =============================================================

    /// @notice Withdraws all native coins from the contract
    /// @dev Only callable by the owner
    function withdrawNative() external;

    // =============================================================
    // View Functions
    // =============================================================

    /// @notice Returns the address of the ActivationManager associated with this router
    /// @return The address of the ActivationManager contract
    function activationManager() external view returns (address);

    /// @notice Returns the destination LayerZero endpoint ID
    /// @dev Used for cross-chain messaging
    /// @return The 32-bit LayerZero endpoint ID of the destination chain
    function destEid() external view returns (uint32);

    /// @notice Quotes the native fee required to send a cross-chain activation message
    /// @param payload The ABI-encoded activation payload
    /// @return nativeFee The native token fee required to send this payload
    function quoteSend(bytes calldata payload, bytes calldata extraOptions) external view returns (uint256 nativeFee);

    // =============================================================
    // Messaging Functions
    // =============================================================

    /// @notice Sends an activation payload cross-chain
    /// @dev Only callable by the ActivationManager. Sends the ABI-encoded (owner, tokenId, rarity) message.
    /// @param payload The ABI-encoded activation payload containing owner, tokenId, and rarity
    function sendTokenActivation(bytes calldata payload, bytes calldata extraOptions) external payable;
}
