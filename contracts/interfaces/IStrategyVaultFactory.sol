// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IStrategyVaultFactory {
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       Deployment          ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function deployVaultDeterministic(bytes32 salt) external returns (address proxyAddress);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Implementation        ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function setImplementation(address _implementation) external;

    function getImplementation() external view returns (address);

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Configuration         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function setConfiguration(address _feeController, address _feeHandler, address _actionRegistry) external;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Vault Info / Checks    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function getDeployedVaultsCount() external view returns (uint256);

    function getUserVaults(address user) external view returns (address[] memory);

    function getUserVaultsCount(address user) external view returns (uint256);

    function getVaultAt(uint256 index) external view returns (address);

    function getUserVaultAt(address user, uint256 index) external view returns (address);

    function isDeployedVault(address vault) external view returns (bool);

    function getDeployedVaults(uint256 offset, uint256 limit) external view returns (address[] memory);
}
