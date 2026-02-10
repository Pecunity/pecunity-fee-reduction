// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { ICryptoOctoRarityRegistry } from "../interfaces/ICryptoOctoRarityRegistry.sol";

contract MockNFT is ERC721, Ownable, ICryptoOctoRarityRegistry {
    uint256 public nextTokenId;

    // Optional: rarity storage
    mapping(uint256 => Rarity) public rarity;

    constructor() ERC721("MockNFT", "MNFT") Ownable(msg.sender) {}

    // -----------------------------
    // Mint new NFT
    // -----------------------------
    function mint(address to, Rarity _rarity) external returns (uint256) {
        nextTokenId++;
        uint256 tokenId = nextTokenId;

        _safeMint(to, tokenId);

        rarity[tokenId] = _rarity;

        return tokenId;
    }

    // Helper: get rarity
    function getRarity(uint256 tokenId) external view returns (Rarity) {
        return rarity[tokenId];
    }
}
