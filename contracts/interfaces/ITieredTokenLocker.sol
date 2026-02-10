// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ITieredTokenLocker {
    // Tier enumeration
    enum Tier {
        None,
        Basic,
        Bronze,
        Silver,
        Gold,
        Diamond
    }

    // Lock information for each user
    struct LockInfo {
        uint256 amount; // Total locked amount
        uint256 lastDepositTime; // Timestamp of last deposit
        Tier currentTier; // Current tier level
        bool exists; // Whether lock exists
    }

    function getLockInfo(
        address user
    ) external view returns (uint256 amount, uint256 unlockTime, Tier tier, bool canUnlock);
}
