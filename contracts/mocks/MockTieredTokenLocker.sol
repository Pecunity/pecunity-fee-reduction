// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../interfaces/ITieredTokenLocker.sol";

contract MockTieredTokenLocker is ITieredTokenLocker {
    // Internal storage for mock lock data
    struct MockLock {
        uint256 amount;
        uint256 unlockTime;
        Tier tier;
        bool canUnlock;
    }

    mapping(address => MockLock) private locks;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃        Mock Setters       ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @notice Set mock lock info for a user
    function setLockInfo(address user, uint256 amount, uint256 unlockTime, Tier tier, bool canUnlock) external {
        locks[user] = MockLock({ amount: amount, unlockTime: unlockTime, tier: tier, canUnlock: canUnlock });
    }

    /// @notice Clear mock lock info
    function clearLockInfo(address user) external {
        delete locks[user];
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃     Interface Function    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function getLockInfo(
        address user
    ) external view override returns (uint256 amount, uint256 unlockTime, Tier tier, bool canUnlock) {
        MockLock memory info = locks[user];

        return (info.amount, info.unlockTime, info.tier, info.canUnlock);
    }
}
