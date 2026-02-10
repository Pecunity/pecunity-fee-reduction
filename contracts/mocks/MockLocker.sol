// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ITieredTokenLocker } from "../interfaces/ITieredTokenLocker.sol";

contract MockLocker is ITieredTokenLocker {
    mapping(address => Tier) public tierOf;

    function setTier(address user, Tier tier) external {
        tierOf[user] = tier;
    }

    function getLockInfo(address user) external view override returns (uint256, uint256, Tier, bool) {
        return (0, 0, tierOf[user], true);
    }
}
