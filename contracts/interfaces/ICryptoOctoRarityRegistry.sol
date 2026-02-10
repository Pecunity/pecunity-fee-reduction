// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ICryptoOctoRarityRegistry {
    enum Rarity {
        Classic,
        Bronze,
        Silver,
        Gold,
        Diamond
    }

    function getRarity(uint256 tokenId) external view returns (Rarity);
}
