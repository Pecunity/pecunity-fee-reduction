// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title MockStrategyVaultFactory
 * @notice Simple mock factory for Hardhat tests
 *
 * Allows marking arbitrary addresses as valid deployed vaults.
 */
contract MockStrategyVaultFactory {
    // Track which addresses are considered valid vaults
    mapping(address => bool) public deployedVaults;

    /**
     * @notice Set a vault address as deployed or not deployed
     */
    function setDeployedVault(address vault, bool deployed) external {
        deployedVaults[vault] = deployed;
    }

    /**
     * @notice Factory check used by FeeReduction contract
     */
    function isDeployedVault(address vault) external view returns (bool) {
        return deployedVaults[vault];
    }
}
