// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC165} from "openzeppelin/utils/introspection/IERC165.sol";

import {IAccount} from "../../src/interfaces/IAccount.sol";

contract MockAccount is IERC165, IAccount {
    bool private _initialized;

    receive() external payable {}

    function initialize(bool val) external {
        if (!val) {
            revert("disabled");
        }
        _initialized = val;
    }

    function executeCall(address, uint256, bytes calldata) external payable returns (bytes memory) {
        revert("disabled");
    }

    function owner() public pure returns (address) {
        revert("disabled");
    }

    function setOwner(address) external pure {
        revert("disabled");
    }

    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        if (interfaceId == 0xffffffff) return false;
        return _initialized;
    }
}
