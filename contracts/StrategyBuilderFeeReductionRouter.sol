// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { OAppOptionsType3 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IStrategyBuilderFeeReduction } from "./interfaces/IStrategyBuilderFeeReduction.sol";
import { IStrategyBuilderFeeReductionRouter } from "./interfaces/IStrategyBuilderFeeReductionRouter.sol";

/**
 * @title StrategyBuilderFeeReductionRouter
 * @author 3Blocks
 *
 * @notice LayerZero cross-chain router for StrategyBuilder fee reduction activations.
 *
 * @dev
 * This contract acts as the messaging bridge between two chains:
 *
 * - Source Chain (e.g. Arbitrum):
 *   Users withdraw/deactivate their NFT-based fee reduction.
 *   The StrategyBuilderFeeReduction contract triggers a cross-chain message.
 *
 * - Destination Chain (e.g. BSC):
 *   The activation is applied again by calling `activateTokenForUser`.
 *
 * The router is responsible for:
 * - Quoting LayerZero native messaging fees
 * - Sending deactivation messages cross-chain
 * - Receiving activation messages from the remote chain
 *
 * Payload format (ABI encoded):
 * ------------------------------------------------------------
 * (address user, uint256 tokenId, uint8 rarity)
 *
 * Security assumptions:
 * - Only LayerZero Endpoint can call `_lzReceive`
 * - Only registered peers are accepted (configured via `setPeer`)
 * - Only the StrategyBuilderFeeReduction contract may send messages
 */
contract StrategyBuilderFeeReductionRouter is OApp, OAppOptionsType3, IStrategyBuilderFeeReductionRouter {
    using OptionsBuilder for bytes;

    /// @notice Msg type for sending a string, for use in OAppOptionsType3 as an enforced option
    uint16 public constant SEND = 1;

    // ──────────────────────────────────────────────────────────────
    // State Variables
    // ──────────────────────────────────────────────────────────────

    /**
     * @notice Address of the StrategyBuilderFeeReduction contract.
     * @dev Only this contract is allowed to trigger outbound messages.
     */
    address public strategyBuilderFeeReduction;

    /**
     * @notice Destination LayerZero Endpoint ID.
     * @dev Defines which remote chain this router communicates with.
     */
    uint32 public destEid;

    // ──────────────────────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────────────────────

    /**
     * @notice Deploys the StrategyBuilderFeeReductionRouter.
     *
     * @param _endpoint The LayerZero EndpointV2 address on the local chain
     * @param _owner The contract owner allowed to configure peers and settings
     * @param _strategyBuilderFeeReduction The fee reduction contract allowed to send messages
     * @param _destEid The LayerZero endpoint ID of the destination chain
     */
    constructor(
        address _endpoint,
        address _owner,
        address _strategyBuilderFeeReduction,
        uint32 _destEid
    ) OApp(_endpoint, _owner) Ownable(_owner) {
        strategyBuilderFeeReduction = _strategyBuilderFeeReduction;
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

    // ──────────────────────────────────────────────────────────────
    // Fee Quoting
    // ──────────────────────────────────────────────────────────────

    /// @notice Quotes the fee and extra options required to send a cross-chain message
    /// @param payload The ABI-encoded payload to be sent
    /// @return nativeFee The fee in native token required to send this message
    function quoteSend(bytes memory payload, bytes calldata extraOptions) public view returns (uint256) {
        MessagingFee memory fee = _quote(destEid, payload, combineOptions(destEid, SEND, extraOptions), false);
        return (fee.nativeFee);
    }

    // ──────────────────────────────────────────────────────────────
    // Outbound Messaging
    // ──────────────────────────────────────────────────────────────

    /**
     * @notice Sends a token deactivation message to the destination chain.
     *
     * @dev
     * Only callable by the StrategyBuilderFeeReduction contract.
     * This is triggered when a user withdraws their NFT activation.
     *
     * Requirements:
     * - Caller must be `strategyBuilderFeeReduction`
     * - Contract must be funded with enough native ETH for LayerZero fees
     *
     * Payload format:
     * (address user, uint256 tokenId, uint8 rarity)
     *
     * @param payload ABI-encoded deactivation payload
     */
    function sendTokenDeactivation(bytes memory payload, bytes calldata extraOptions) external payable {
        if (msg.sender != strategyBuilderFeeReduction) {
            revert NotAllowed();
        }

        uint256 fee = quoteSend(payload, extraOptions);

        _lzSend(destEid, payload, extraOptions, MessagingFee(fee, 0), payable(msg.sender));
    }

    // ──────────────────────────────────────────────────────────────
    // Inbound Messaging (LayerZero Receive)
    // ──────────────────────────────────────────────────────────────

    /**
     * @notice Handles incoming activation messages from the remote chain.
     *
     * @dev
     * This function is invoked automatically by the LayerZero Endpoint.
     *
     * The base LayerZero receiver guarantees:
     * - Only the Endpoint can call this function
     * - The sender is a registered trusted peer
     *
     * Decodes the payload and activates the token for the user on this chain.
     *
     * Expected payload format:
     * (address user, uint256 tokenId, uint8 rarity)
     *
     * Calls:
     * `StrategyBuilderFeeReduction.activateTokenForUser(user, tokenId, rarity)`
     *
     * @param _message ABI-encoded activation payload
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (address user, uint256 tokenId, uint8 rarity) = abi.decode(_message, (address, uint256, uint8));

        IStrategyBuilderFeeReduction(payable(strategyBuilderFeeReduction)).activateTokenForUser(user, tokenId, rarity);
    }
}
