// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IAccountProxy {
    function implementation() external view returns (address);
}

interface IAccount {
    event TransactionExecuted(address indexed target, uint256 indexed value, bytes data);

    receive() external payable;

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory);

    function owner() external view returns (address);

    function setOwner(address newOwner) external;
}
