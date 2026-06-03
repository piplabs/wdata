// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

import { ERC20 } from "solady/src/tokens/ERC20.sol";

/// @notice Wrapped DATA implementation. Rebrand of WIP; the underlying native token is unchanged.
/// @author Inspired by WETH9 (https://github.com/dapphub/ds-weth/blob/master/src/weth9.sol)
contract WDATA is ERC20 {

    /// @notice emitted when native DATA is deposited in exchange for WDATA
    event Deposit(address indexed from, uint amount);
    /// @notice emitted when WDATA is withdrawn in exchange for native DATA
    event Withdrawal(address indexed to, uint amount);

    /// @notice emitted when a transfer of native DATA fails
    error DATATransferFailed();
    /// @notice emitted when an invalid transfer recipient is detected
    error ERC20InvalidReceiver(address receiver);
    /// @notice emitted when an invalid transfer spender is detected
    error ERC20InvalidSpender(address spender);

    /// @notice triggered when native DATA is sent to this contract
    receive() external payable {
        deposit();
    }

    /// @notice deposits native DATA in exchange for WDATA
    /// @dev the amount of WDATA minted is equal to msg.value
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice withdraws WDATA in exchange for native DATA
    /// @dev the amount of native DATA returned is equal to the amount of WDATA burned
    /// @param value the amount of WDATA to burn and withdraw
    function withdraw(uint value) external {
        _burn(msg.sender, value);
        (bool success, ) = msg.sender.call{ value: value }("");
        if (!success) {
            revert DATATransferFailed();
        }
        emit Withdrawal(msg.sender, value);
    }

    /// @notice returns the name of the token
    function name() public pure override returns (string memory) {
        return "Wrapped DATA";
    }

    /// @notice returns the symbol of the token
    function symbol() public pure override returns (string memory) {
        return "WDATA";
    }

    /// @notice approves `spender` to spend `amount` of WDATA
    function approve(address spender, uint256 amount) public override returns (bool) {
        if (spender == msg.sender) {
            revert ERC20InvalidSpender(msg.sender);
        }

        return super.approve(spender, amount);
    }

    /// @notice transfers `amount` of WDATA to a recipient `to`
    function transfer(address to, uint256 amount) public override returns (bool) {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        if (to == address(this)) {
            revert ERC20InvalidReceiver(address(this));
        }

        return super.transfer(to, amount);
    }

    /// @notice transfers `amount` of WDATA from `from` to a recipient `to`
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        if (to == address(this)) {
            revert ERC20InvalidReceiver(address(this));
        }

        return super.transferFrom(from, to, amount);
    }

    /// @dev Sets Permit2 contract's allowance to infinity.
    function _givePermit2InfiniteAllowance() internal pure override returns (bool) {
        return true;
    }
}
