// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

import { CREATE3 } from "solady/src/utils/CREATE3.sol";

/// @notice CREATE3 factory for deploying contracts to addresses that depend only on a salt,
///         not on the contract's initialization code.
/// @dev ABI-compatible with Story Protocol's Create3 factory, backed by solady's CREATE3.
///      `deploy`/`getDeployed` namespace the salt with the caller; `deployDeterministic`/
///      `predictDeterministicAddress` use the salt directly for a sender-independent address.
/// @custom:attribution zefram.eth (https://github.com/ZeframLou/create3-factory)
contract Create3 {
    /// @notice deploys `creationCode` via CREATE3 in the caller's namespace
    function deploy(bytes32 salt, bytes memory creationCode) external payable returns (address deployed) {
        salt = keccak256(abi.encodePacked(msg.sender, salt));
        return CREATE3.deployDeterministic(msg.value, creationCode, salt);
    }

    /// @notice predicts the address `deploy` would produce for `deployer` and `salt`
    function getDeployed(address deployer, bytes32 salt) external view returns (address deployed) {
        salt = keccak256(abi.encodePacked(deployer, salt));
        return CREATE3.predictDeterministicAddress(salt, address(this));
    }

    /// @notice deploys `creationCode` via CREATE3 using `salt` directly
    function deployDeterministic(bytes memory creationCode, bytes32 salt) external payable returns (address deployed) {
        return CREATE3.deployDeterministic(msg.value, creationCode, salt);
    }

    /// @notice predicts the address `deployDeterministic` would produce for `salt`
    function predictDeterministicAddress(bytes32 salt) external view returns (address deployed) {
        return CREATE3.predictDeterministicAddress(salt, address(this));
    }
}
