// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract ActivateTokenMockReceiver is OApp {
    // gespeicherte letzte Werte (nur zum Test)
    address public lastOwner;
    uint256 public lastTokenId;
    uint8 public lastRarity;
    bytes public lastMessage;

    event MessageReceived(address owner, uint256 tokenId, uint8 rarity);

    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) Ownable(_owner) {}

    // -----------------------------
    // LayerZero Receive
    // -----------------------------
    function _lzReceive(
        Origin calldata /*origin*/,
        bytes32 /*guid*/,
        bytes calldata message,
        address /*executor*/,
        bytes calldata /*extraData*/
    ) internal override {
        if (message.length == 0) {
            revert("Empty message");
        }

        // Decode payload from Arbitrum
        (address owner, uint256 tokenId, uint8 rarity) = abi.decode(message, (address, uint256, uint8));

        // Save values (for testing)
        // lastMessage = message;
        lastOwner = owner;
        lastTokenId = tokenId;
        lastRarity = rarity;

        // Emit event (best for debugging)
        emit MessageReceived(owner, tokenId, 0);
    }
}
