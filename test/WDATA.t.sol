// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { WDATA } from "../src/WDATA.sol";

contract WDATATest is Test {
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    WDATA internal wdata;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    event Deposit(address indexed from, uint amount);
    event Withdrawal(address indexed to, uint amount);

    function setUp() public {
        wdata = new WDATA();
        vm.deal(alice, 1_000 ether);
        vm.deal(bob, 1_000 ether);
    }

    // ---------- deposit / receive ----------

    function test_Deposit_MintsAndEmits() public {
        vm.expectEmit(true, false, false, true, address(wdata));
        emit Deposit(alice, 5 ether);

        vm.prank(alice);
        wdata.deposit{ value: 5 ether }();

        assertEq(wdata.balanceOf(alice), 5 ether);
        assertEq(wdata.totalSupply(), 5 ether);
        assertEq(address(wdata).balance, 5 ether);
    }

    function test_Receive_MintsAndEmits() public {
        vm.expectEmit(true, false, false, true, address(wdata));
        emit Deposit(alice, 3 ether);

        vm.prank(alice);
        (bool ok, ) = address(wdata).call{ value: 3 ether }("");
        assertTrue(ok);

        assertEq(wdata.balanceOf(alice), 3 ether);
    }

    // ---------- withdraw ----------

    function test_Withdraw_BurnsAndReturnsNative() public {
        vm.prank(alice);
        wdata.deposit{ value: 5 ether }();

        uint256 balBefore = alice.balance;

        vm.expectEmit(true, false, false, true, address(wdata));
        emit Withdrawal(alice, 2 ether);

        vm.prank(alice);
        wdata.withdraw(2 ether);

        assertEq(wdata.balanceOf(alice), 3 ether);
        assertEq(alice.balance, balBefore + 2 ether);
        assertEq(address(wdata).balance, 3 ether);
    }

    function test_Withdraw_RevertsWhenRecipientRejects() public {
        RejectingReceiver rr = new RejectingReceiver();
        vm.deal(address(rr), 1 ether);

        vm.prank(address(rr));
        wdata.deposit{ value: 1 ether }();

        vm.prank(address(rr));
        vm.expectRevert(WDATA.DATATransferFailed.selector);
        wdata.withdraw(1 ether);
    }

    // ---------- name / symbol ----------

    function test_NameAndSymbol() public view {
        assertEq(wdata.name(), "Wrapped DATA");
        assertEq(wdata.symbol(), "WDATA");
    }

    // ---------- approve / transfer guards ----------

    function test_Approve_RevertsOnSelfSpender() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(WDATA.ERC20InvalidSpender.selector, alice));
        wdata.approve(alice, 1 ether);
    }

    function test_Transfer_RevertsOnZero() public {
        vm.prank(alice);
        wdata.deposit{ value: 1 ether }();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(WDATA.ERC20InvalidReceiver.selector, address(0)));
        wdata.transfer(address(0), 1);
    }

    function test_Transfer_RevertsOnSelfContract() public {
        vm.prank(alice);
        wdata.deposit{ value: 1 ether }();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(WDATA.ERC20InvalidReceiver.selector, address(wdata)));
        wdata.transfer(address(wdata), 1);
    }

    function test_TransferFrom_RevertsOnZero() public {
        vm.prank(alice);
        wdata.deposit{ value: 1 ether }();
        vm.prank(alice);
        wdata.approve(bob, 1 ether);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(WDATA.ERC20InvalidReceiver.selector, address(0)));
        wdata.transferFrom(alice, address(0), 1);
    }

    function test_TransferFrom_RevertsOnSelfContract() public {
        vm.prank(alice);
        wdata.deposit{ value: 1 ether }();
        vm.prank(alice);
        wdata.approve(bob, 1 ether);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(WDATA.ERC20InvalidReceiver.selector, address(wdata)));
        wdata.transferFrom(alice, address(wdata), 1);
    }

    // ---------- Permit2 infinite allowance ----------

    function test_Permit2InfiniteAllowance() public view {
        assertEq(wdata.allowance(alice, PERMIT2), type(uint256).max);
    }
}

contract RejectingReceiver {
    receive() external payable {
        revert("nope");
    }
}
