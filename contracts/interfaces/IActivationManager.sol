// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @title IActivationManager
/// @author 3Blocks
/// @notice Interface for managing NFT activation locks across chains.
/// @dev
/// The ActivationManager is responsible for:
/// - Locking an NFT on the source chain (e.g. Arbitrum)
/// - Sending an activation message via LayerZero to the destination chain (e.g. BSC)
/// - Unlocking and returning the NFT when a deactivation message is received
///
/// This interface is designed to be called by:
/// - Users (activateToken)
/// - The ActivationRouter (deactivateToken)
///
/// The locked NFT serves as proof of activation, enabling benefits such as
/// fee reductions or tier upgrades on the destination chain.
interface IActivationManager {
    // =============================================================
    // Errors
    // =============================================================

    /// @notice Thrown when the caller is not the owner of the NFT.
    error NotOwnerOfToken();

    /// @notice Thrown when the contract does not have enough native gas
    ///         funds to pay the LayerZero messaging fee.
    error OutOfFunds();

    /// @notice Thrown when the NFT rarity does not meet the minimum
    ///         requirement (only Gold or Diamond allowed).
    error RarityNotGoldOrDiamond();

    /// @notice Thrown when a restricted function is called by an
    ///         unauthorized address (e.g. not the router).
    error NotAllowed();

    // =============================================================
    // Structs
    // =============================================================

    /// @notice Stores information about a locked token.
    /// @param tokenId The NFT identifier that is currently locked
    /// @param rarity  The rarity tier of the NFT (used for benefits on destination chain)
    struct TokenInfo {
        uint256 tokenId;
        uint8 rarity;
    }

    // =============================================================
    // View Functions
    // =============================================================

    /// @notice Returns the router contract responsible for cross-chain messaging.
    /// @dev The router is the only entity allowed to trigger deactivation/unlock.
    function router() external view returns (address);

    // =============================================================
    // Core Activation Logic
    // =============================================================

    /// @notice Locks the caller’s NFT and triggers a cross-chain activation message.
    /// @dev
    /// Requirements:
    /// - Caller must own the NFT
    /// - NFT rarity must be Gold or Diamond
    /// - Contract must have enough ETH to pay LayerZero fees
    ///
    /// Effects:
    /// - Transfers the NFT into this contract (locks it)
    /// - Stores activation metadata
    /// - Sends (owner, tokenId, rarity) to the router for delivery
    ///
    /// @param tokenId The NFT tokenId to activate and lock.
    function activateToken(uint256 tokenId, uint128 customGasLimit) external;

    /// @notice Unlocks a previously locked NFT and returns it to the user.
    /// @dev
    /// This function is only callable by the router after receiving a valid
    /// deactivation message from the destination chain.
    ///
    /// Effects:
    /// - Transfers the NFT back to the original owner
    /// - Clears the stored lock information
    ///
    /// @param user    The owner address that should receive the unlocked NFT.
    /// @param tokenId The NFT tokenId to deactivate and unlock.
    function deactivateToken(address user, uint256 tokenId) external;

    // =============================================================
    // Fallback Functions
    // =============================================================

    /// @notice Allows the contract to receive native tokens for LayerZero fees.
    receive() external payable;

    /// @notice Fallback function to accept ETH transfers and unknown calls.
    fallback() external payable;
}
