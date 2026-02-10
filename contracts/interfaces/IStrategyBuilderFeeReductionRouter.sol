// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IStrategyBuilderFeeReductionRouter
 * @author 3Blocks
 *
 * @notice Interface for the LayerZero Router responsible for
 * cross-chain activation/deactivation messaging for StrategyBuilderFeeReduction.
 *
 * This router:
 * - Sends token deactivation messages back to the origin chain
 * - Receives token activation messages from the origin chain
 * - Forwards activation data into the FeeReduction contract
 */
interface IStrategyBuilderFeeReductionRouter {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃              Errors              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Caller is not allowed (only FeeReduction contract may call)
    error NotAllowed();

    /// @notice Thrown when the owner tries to set an invalid gas limit
    error GasLimitTooLow();

    /// @notice Thrown when trying to withdraw with zero balance
    error NoFundsToWithdraw();

    /// @notice Thrown when native transfer fails
    error WithdrawFailed();

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃              Events              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Emitted when the owner withdraws native funds
    event NativeWithdrawn(address indexed owner, uint256 amount);

    /// @notice Emitted when the owner updates the gas limit for LayerZero receive execution
    /// @param oldGasLimit Previous configured gas limit
    /// @param newGasLimit New configured gas limit
    event GasLimitUpdated(uint128 oldGasLimit, uint128 newGasLimit);

    /**
     * @notice Emitted when a deactivation message is sent cross-chain.
     *
     * @param user    The user whose token is being deactivated
     * @param tokenId The tokenId being withdrawn
     * @param rarity  The rarity of the token
     */
    event TokenDeactivationSent(address indexed user, uint256 indexed tokenId, uint8 rarity);

    /**
     * @notice Emitted when an activation message is received from another chain.
     *
     * @param user    The user receiving activation
     * @param tokenId The activated tokenId
     * @param rarity  The rarity of the activated NFT
     */
    event TokenActivationReceived(address indexed user, uint256 indexed tokenId, uint8 rarity);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        State Variables           ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Returns the connected StrategyBuilderFeeReduction contract.
     */
    function strategyBuilderFeeReduction() external view returns (address);

    /**
     * @notice Returns the destination LayerZero endpoint ID.
     */
    function destEid() external view returns (uint32);

    // =============================================================
    // Owner Withdraw
    // =============================================================

    /// @notice Withdraws all native coins from the contract
    /// @dev Only callable by the owner
    function withdrawNative() external;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Messaging Functions       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @notice Quotes the LayerZero native fee required to send a message.
     *
     * @param payload The encoded cross-chain message payload
     *
     * @return nativeFee     The required native gas fee
     */
    function quoteSend(bytes memory payload, bytes calldata extraOptions) external view returns (uint256);

    /**
     * @notice Sends a token deactivation message to the origin chain.
     *
     * @dev Callable only by the StrategyBuilderFeeReduction contract.
     *
     * Requirements:
     * - Caller must equal strategyBuilderFeeReduction
     * - Must provide enough msg.value for LayerZero fees
     *
     * @param payload Encoded message containing (user, tokenId, rarity)
     */
    function sendTokenDeactivation(bytes memory payload, bytes calldata extraOptions) external payable;
}
