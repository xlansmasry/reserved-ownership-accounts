// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IAccountRegistryFactory {
    event AccountRegistryCreated(address registry, address implementation, uint256 index);

    function createRegistry(
        address accountImplementation,
        uint256 index
    ) external returns (address);

    function registry(address deployer, uint256 index) external view returns (address);
}
