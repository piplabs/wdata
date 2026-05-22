// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

/// @notice Minimal interface for the existing Wrapped IP token used by WDATA.migrate.
interface IWIP {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function withdraw(uint256 value) external;
}
