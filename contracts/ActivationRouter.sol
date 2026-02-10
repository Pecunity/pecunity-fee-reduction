// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { OAppOptionsType3 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IActivationRouter } from "./interfaces/IActivationRouter.sol";
import { IActivationManager } from "./interfaces/IActivationManager.sol";

/// @title ActivationRouter
/// @author 3Blocks
/// @notice Router contract for LayerZero cross-chain messaging of NFT activations
/// @dev
/// - Receives activation requests from the ActivationManager
/// - Sends encoded messages to the destination chain LayerZero endpoint
/// - Can receive messages from the destination chain to trigger NFT deactivation
contract ActivationRouter is OApp, OAppOptionsType3, IActivationRouter {
    /// @notice Msg type for sending a string, for use in OAppOptionsType3 as an enforced option
    uint16 public constant SEND = 1;

    /// @notice The ActivationManager allowed to call `sendTokenActivation`
    address public activationManager;

    /// @notice Destination chain LayerZero endpoint ID
    uint32 public destEid;

    // =============================================================
    // Constructor
    // =============================================================

    /// @notice Initializes the router with endpoint, owner, and activation manager
    /// @param _endpoint The LayerZero endpoint address for this chain
    /// @param _owner The contract owner (for configuration purposes)
    /// @param _activationManager The ActivationManager contract allowed to send messages
    /// @param _destEid The LayerZero endpoint ID of the destination chain
    constructor(
        address _endpoint,
        address _owner,
        address _activationManager,
        uint32 _destEid
    ) OApp(_endpoint, _owner) Ownable(_owner) {
        activationManager = _activationManager;
        destEid = _destEid;
    }

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
    // View / Helper Functions
    // =============================================================

    /// @notice Quotes the fee and extra options required to send a cross-chain message
    /// @param payload The ABI-encoded payload to be sent
    /// @return nativeFee The fee in native token required to send this message
    function quoteSend(bytes memory payload, bytes calldata extraOptions) public view returns (uint256) {
        MessagingFee memory fee = _quote(destEid, payload, combineOptions(destEid, SEND, extraOptions), false);
        return (fee.nativeFee);
    }

    // =============================================================
    // Messaging Functions
    // =============================================================

    /// @notice Sends a cross-chain activation message to the destination chain
    /// @dev Only callable by the configured `activationManager`
    /// @param payload The ABI-encoded activation data (user, tokenId, rarity)
    function sendTokenActivation(bytes memory payload, bytes calldata extraOptions) external payable {
        if (msg.sender != activationManager) {
            revert NotAllowed();
        }

        uint256 fee = quoteSend(payload, extraOptions);

        _lzSend(destEid, payload, extraOptions, MessagingFee(fee, 0), payable(msg.sender));
    }

    // =============================================================
    // LayerZero Receive
    // =============================================================

    /// @notice Handles incoming LayerZero messages from the destination chain
    /// @dev Overrides OApp._lzReceive
    /// @param _message The ABI-encoded payload sent from the source chain
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        // Decode payload containing the user and tokenId
        (address user, uint256 tokenId) = abi.decode(_message, (address, uint256));

        // Call the ActivationManager to deactivate the token
        IActivationManager(payable(activationManager)).deactivateToken(user, tokenId);
    }
}
