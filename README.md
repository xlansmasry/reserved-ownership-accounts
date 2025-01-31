---
title: Reserved Ownership Accounts
description: A registry for generating future-deployed smart contract accounts owned by users on external services
author: Paul Sullivan (@sullivph) <paul.sullivan@manifold.xyz>, Wilkins Chung (@wwchung) <wilkins@manifold.xyz>, Kartik Patel (@Slokh) <kartik@manifold.xyz>
discussions-to: <URL>
status: Draft
type: Standards Track
category: ERC
created: 2023-04-25
requires: 1167, 1271
---

## Abstract

The following specifies a system for services to provide their users with a deterministic wallet address tied to identifying credentials (e.g. email address, phone number, etc.) without any blockchain interaction, and a mechanism to deploy and control a smart contract wallet (Account Instance) at the deterministic address in the future.

## Motivation

It is common for web services to allow their users to hold on-chain assets via custodial wallets. These wallets are typically EOAs, deployed smart contract wallets or omnibus contracts, with private keys or asset ownership information stored on a traditional database. This proposal outlines a solution that avoids the security concerns associated with historical approaches, and rids the need and implications of services controlling user assets

Users on external services that choose to leverage the following specification can be given an Ethereum address to receive assets without the need to do any on-chain transaction. These users can choose to attain control of said addresses at a future point in time. Thus, on-chain assets can be sent to and owned by a user beforehand, therefore enabling the formation of an on-chain identity without requiring the user to interact with the underlying blockchain.

## Specification

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119 and RFC 8174.

### Overview

The system for creating deferred custody accounts consists of:

1. An Account Registry which provides a deterministic smart contract address for an external service based on an identifying salt, and a function guarded by verifiable signatures that allows for the deployment and control of Account Instances by the end user.
2. Account Instances created by the Account Registry for the end user which allow access to the assets received at the deterministic address prior to Account Instance deployment and ownership assignment.

External services wishing to provide their users with reserved ownership accounts MUST maintain a relationship between a user's identifying credentials and a salt. The external service SHALL refer to an Account Registry Instance to retrieve the deterministic account address for a given salt. Users from a given service MUST be able to create an Account Instance by validating their identifying credentials via the external service, which SHOULD give the user a valid signature for their salt. Users SHALL pass this signature to the service's Account Registry Instance in a call to `claimAccount` to claim ownership of an Account Instance at the deterministic address.

### Account Registry
The Account Registry MUST implement the following interface:

```solidity
interface IAccountRegistry {
    /**
     * @dev Registry instances emit the AccountCreated event upon successful account creation
     */
    event AccountCreated(address account, address accountImplementation, uint256 salt);

    /**
     * @dev Registry instances emit the AccountClaimed event upon successful claim of account by owner
     */
    event AccountClaimed(address account, address owner);

    /**
     * @dev Creates a smart contract account.
     *
     * If account has already been created, returns the account address without calling create2.
     *
     * @param salt       - The identifying salt for which the user wishes to deploy an Account Instance
     *
     * Emits AccountCreated event
     * @return the address for which the Account Instance was created
     */
    function createAccount(uint256 salt) external returns (address);

    /**
     * @dev Allows an owner to claim a smart contract account created by this registry.
     *
     * If the account has not already been created, the account will be created first using `createAccount`
     *
     * @param owner      - The initial owner of the new Account Instance
     * @param salt       - The identifying salt for which the user wishes to deploy an Account Instance
     * @param expiration - If expiration > 0, represents expiration time for the signature.  Otherwise
     *                     signature does not expire.
     * @param message    - The keccak256 message which validates the owner, salt, expiration
     * @param signature  - The signature which validates the owner, salt, expiration
     *
     * Emits AccountClaimed event
     * @return the address of the claimed Account Instance
     */
    function claimAccount(
        address owner,
        uint256 salt,
        uint256 expiration,
        bytes32 message,
        bytes calldata signature
    ) external returns (address);

    /**
     * @dev Returns the computed address of a smart contract account for a given identifying salt
     *
     * @return the computed address of the account
     */
    function account(uint256 salt) external view returns (address);

    /**
     * @dev Fallback signature verification for unclaimed accounts
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4);
}
```

- The Account Registry MUST use an immutable account implementation address.
- `createAccount` SHOULD deploy new Account Instances as [EIP-1167](https://eips.ethereum.org/EIPS/eip-1167) proxies
- `claimAccount` SHOULD verify that the msg.sender has permission to claim ownership over the Account Instance for the identifying salt and initial owner. Verification SHOULD be done by validating the message and signature against the owner, salt and expiration using ECDSA for EOA signers, or EIP-1271 for smart contract signers
- `claimAccount` SHOULD verify that the block.timestamp < expiration or that expiration == 0
- Upon successful signature verification on calls to `claimAccount`, the registry MUST completely relinquish control over the Account Instance, and assign ownership to the initial owner by calling `setOwner` on the Account Instance

### Account Instance
The Account Instance MUST implement the following interface:

```solidity
interface IAccount {
    /**
     * @dev Sets the owner of the Account Instance.
     *
     * Only callable by the current owner of the instance, or by the registry if the Account
     * Instance has not yet been claimed.
     *
     * @param owner      - The new owner of the Account Instance
     */
    function setOwner(address owner) external;
}
```

- All Account Instances MUST be created using an Account Registry Instance
- `setOwner` SHOULD be callable by the current owner of the Account Instance, and MUST be callable by the deploying Account Registry Instance if the Account Instance has not yet been claimed
- Account Instance SHOULD support [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271)
- Account Instance SHOULD provide access to assets previously sent to the address at which the Account Instance is deployed to

## Rationale

### Service-Owned Registry Instances

While it might seem more user-friendly to implement and deploy a universal registry for reserved ownership accounts, we believe that it is important for external service providers to have the option to own and control their own Account Registry.  This provides the flexibility of implementing their own permission controls and account deployment authorization frameworks.

We are providing a reference Registry Factory which can deploy Account Registries for an external service, which comes with:
- Immutable Account Instance implementation
- Validation for the `claimAccount` method via ECDSA for EOA signers, or ERC-1271 validation for smart contract signers
- Ability for the Account Registry deployer to change the signing addressed used for `claimAccount` validation

### Account Registry and Account Implementation Coupling

Since Account Instances are deployed as [ERC-1167](https://eips.ethereum.org/EIPS/eip-1167) proxies, the account implementation address affects the addresses of accounts deployed from a given Account Registry. Requiring that registry instances be linked to a single, immutable account implementation ensures consistency between a user's salt and linked address on a given Account Registry Instance.

This also allows services to gain the the trust of users by deploying their registries with a reference to a trusted account implementation address.

Furthermore, account implementations can be designed as upgradeable, so users are not necessarily bound to the implementation specified by the Account Registry Instance used to create their account.

### Separate `createAccount` and `claimAccount` Operations

Operations to create and claim Account Instances are intentionally separate. This allows services to provide users with valid [ERC-6492](https://eips.ethereum.org/EIPS/eip-6492) signatures before the Account Instance has been deployed or claimed.

## Reference Implementation

The following is an example of an Account Registry Factory which can be used by external service providers to deploy their own Account Registry Instance.

### Account Registry Factory

```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.13;

/// @author: manifold.xyz

import {Create2} from "openzeppelin/utils/Create2.sol";

import {Address} from "../../lib/Address.sol";
import {ERC1167ProxyBytecode} from "../../lib/ERC1167ProxyBytecode.sol";
import {IAccountRegistryFactory} from "./IAccountRegistryFactory.sol";

contract AccountRegistryFactory is IAccountRegistryFactory {
    using Address for address;

    error InitializationFailed();

    address private immutable registryImplementation = 0x076B08EDE2B28fab0c1886F029cD6d02C8fF0E94;

    function createRegistry(
        uint96 index,
        address accountImplementation,
        bytes calldata accountInitData
    ) external returns (address) {
        bytes32 salt = _getSalt(msg.sender, index);
        bytes memory code = ERC1167ProxyBytecode.createCode(registryImplementation);
        address _registry = Create2.computeAddress(salt, keccak256(code));

        if (_registry.isDeployed()) return _registry;

        _registry = Create2.deploy(0, salt, code);

        (bool success, ) = _registry.call(
            abi.encodeWithSignature(
                "initialize(address,address,bytes)",
                msg.sender,
                accountImplementation,
                accountInitData
            )
        );
        if (!success) revert InitializationFailed();

        emit AccountRegistryCreated(_registry, accountImplementation, index);

        return _registry;
    }

    function registry(address deployer, uint96 index) external view override returns (address) {
        bytes32 salt = _getSalt(deployer, index);
        bytes memory code = ERC1167ProxyBytecode.createCode(registryImplementation);
        return Create2.computeAddress(salt, keccak256(code));
    }

    function _getSalt(address deployer, uint96 index) private pure returns (bytes32) {
        return bytes32(abi.encodePacked(deployer, index));
    }
}
```

### Account Registry

```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.13;

/// @author: manifold.xyz

import {Create2} from "openzeppelin/utils/Create2.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {IERC1271} from "openzeppelin/interfaces/IERC1271.sol";
import {SignatureChecker} from "openzeppelin/utils/cryptography/SignatureChecker.sol";

import {Address} from "../../lib/Address.sol";
import {IAccountRegistry} from "../../interfaces/IAccountRegistry.sol";
import {ERC1167ProxyBytecode} from "../../lib/ERC1167ProxyBytecode.sol";

contract AccountRegistryImplementation is Ownable, Initializable, IAccountRegistry {
    using Address for address;
    using ECDSA for bytes32;

    struct Signer {
        address account;
        bool isContract;
    }

    error InitializationFailed();
    error ClaimFailed();
    error Unauthorized();

    address public accountImplementation;
    bytes public accountInitData;
    Signer public signer;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        address accountImplementation_,
        bytes calldata accountInitData_
    ) external initializer {
        _transferOwnership(owner);
        accountImplementation = accountImplementation_;
        accountInitData = accountInitData_;
    }

    /**
     * @dev See {IAccountRegistry-createAccount}
     */
    function createAccount(uint256 salt) external override returns (address) {
        bytes memory code = ERC1167ProxyBytecode.createCode(accountImplementation);
        address _account = Create2.computeAddress(bytes32(salt), keccak256(code));

        if (_account.isDeployed()) return _account;

        _account = Create2.deploy(0, bytes32(salt), code);

        (bool success, ) = _account.call(accountInitData);
        if (!success) revert InitializationFailed();

        emit AccountCreated(_account, accountImplementation, salt);

        return _account;
    }

    /**
     * @dev See {IAccountRegistry-claimAccount}
     */
    function claimAccount(
        address owner,
        uint256 salt,
        uint256 expiration,
        bytes32 message,
        bytes calldata signature
    ) external override returns (address) {
        _verify(owner, salt, expiration, message, signature);
        address _account = this.createAccount(salt);

        (bool success, ) = _account.call(
            abi.encodeWithSignature("transferOwnership(address)", owner)
        );
        if (!success) revert ClaimFailed();

        emit AccountClaimed(_account, owner);
        return _account;
    }

    /**
     * @dev See {IAccountRegistry-account}
     */
    function account(uint256 salt) external view override returns (address) {
        bytes memory code = ERC1167ProxyBytecode.createCode(accountImplementation);
        return Create2.computeAddress(bytes32(salt), keccak256(code));
    }

    /**
     * @dev See {IAccountRegistry-isValidSignature}
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        bool isValid = SignatureChecker.isValidSignatureNow(signer.account, hash, signature);
        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }

    function updateSigner(address newSigner) external onlyOwner {
        uint32 signerSize;
        assembly {
            signerSize := extcodesize(newSigner)
        }
        signer.account = newSigner;
        signer.isContract = signerSize > 0;
    }

    function _verify(
        address owner,
        uint256 salt,
        uint256 expiration,
        bytes32 message,
        bytes calldata signature
    ) internal view {
        address signatureAccount;

        if (signer.isContract) {
            if (!SignatureChecker.isValidSignatureNow(signer.account, message, signature))
                revert Unauthorized();
        } else {
            signatureAccount = message.recover(signature);
        }

        bytes32 expectedMessage = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n84", owner, salt, expiration)
        );

        if (
            message != expectedMessage ||
            (!signer.isContract && signatureAccount != signer.account) ||
            (expiration != 0 && expiration < block.timestamp)
        ) revert Unauthorized();
    }
}
```

### Example Account Implementation

```solidity
// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.13;

/// @author: manifold.xyz

import {IERC1271} from "openzeppelin/interfaces/IERC1271.sol";
import {SignatureChecker} from "openzeppelin/utils/cryptography/SignatureChecker.sol";
import {IERC165} from "openzeppelin/utils/introspection/IERC165.sol";
import {ERC165Checker} from "openzeppelin/utils/introspection/ERC165Checker.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IERC1967Account} from "./IERC1967Account.sol";

/**
 * @title ERC1967AccountImplementation
 * @notice A lightweight, upgradeable smart contract wallet implementation
 */
contract ERC1967AccountImplementation is
    IERC165,
    IERC721Receiver,
    IERC1155Receiver,
    IERC1967Account,
    IERC1271,
    Initializable,
    Ownable
{
    address public registry;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        registry = msg.sender;
        _transferOwnership(registry);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return (interfaceId == type(IERC1967Account).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev {See IAccount-executeCall}
     */
    function executeCall(
        address _target,
        uint256 _value,
        bytes calldata _data
    ) external payable override onlyOwner returns (bytes memory _result) {
        bool success;
        // solhint-disable-next-line avoid-low-level-calls
        (success, _result) = _target.call{value: _value}(_data);
        require(success, string(_result));
        emit TransactionExecuted(_target, _value, _data);
        return _result;
    }

    receive() external payable {}

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        if (owner() == registry) {
            return IERC1271(registry).isValidSignature(hash, signature);
        }

        bool isValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);
        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }
}
```

## Usage Example

As an external service wishing to provide users with reserved ownership accounts, one could deploy an Account Registry Instance by calling `createRegistry` on the factory contract deployed at address `TBD` with the account implementation located at `TBD`. One would then set the signer on the newly created registry to the public key of an EOA or the address of a contract signer under their control. One would also devise a system to map unique `salt` values to each user (e.g. by taking the `keccak256` value of the user's ID).

The service can now associate each user with an Ethereum address without requiring the user to create or link an EOA. This is particularly useful for services without a crypto-native audience that wish to afford their users the benefits of on-chain ownership and history. For example, a social media service could mint user posts to their reserved ownership accounts as NFTs.

The service can provide an interface for users to claim ownership over their addresses when they are ready to do so. The interface would provide valid calldata to the user, and initiate the `claimAccount` transaction on the Account Registry Instance based on the user's browser wallet, the `salt` linked to the user, and the signer controlled by the service. After the transaction succeeds, the service maintains no control over the address.

## Security Considerations

### Front-running

Deployment of reserved ownership accounts through an Account Registry Instance through calls to `claimAccount` could be front-run by a malicious actor. However, if the malicious actor attempted to alter the `owner` parameter in the calldata, the Account Registry Instance would find the signature to be invalid, and revert the transaction. Thus, any successful front-running transaction would deploy an identical Account Instance to the original transaction, and the original owner would still gain control over the address.

## Copyright

Copyright and related rights waived via [CC0](../LICENSE.md).
