// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IFeeReduction {
    function getFeeReduction(address wallet) external view returns (uint256);
}
