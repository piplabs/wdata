// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { WDATA } from "../src/WDATA.sol";
import { WIP } from "./mocks/WIP.sol";

contract WDATATest is Test {
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    WIP internal wip;
    WDATA internal wdata;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    event Deposit(address indexed from, uint amount);
    event Withdrawal(address indexed to, uint amount);
    event Migrated(address indexed user, uint amount);

    function setUp() public {
        wip = new WIP();
        wdata = new WDATA(address(wip));
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
        vm.expectRevert(WDATA.IPTransferFailed.selector);
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

    // ---------- migrate ----------

    function test_Migrate_HappyPath() public {
        vm.prank(alice);
        wip.deposit{ value: 10 ether }();
        assertEq(wip.balanceOf(alice), 10 ether);

        vm.prank(alice);
        wip.approve(address(wdata), 10 ether);

        vm.expectEmit(true, false, false, true, address(wdata));
        emit Migrated(alice, 10 ether);

        vm.prank(alice);
        wdata.migrate(10 ether);

        assertEq(wip.balanceOf(alice), 0);
        assertEq(wdata.balanceOf(alice), 10 ether);
        assertEq(wdata.totalSupply(), 10 ether);
        assertEq(address(wdata).balance, 10 ether);
        assertEq(address(wip).balance, 0);
    }

    function test_Migrate_RevertsWithoutApproval() public {
        vm.prank(alice);
        wip.deposit{ value: 5 ether }();

        vm.prank(alice);
        vm.expectRevert();
        wdata.migrate(5 ether);
    }

    function test_Migrate_ZeroAmount() public {
        vm.prank(alice);
        wip.approve(address(wdata), 0);

        vm.prank(alice);
        wdata.migrate(0);

        assertEq(wdata.balanceOf(alice), 0);
        assertEq(wdata.totalSupply(), 0);
    }

    function test_Migrate_DoesNotMintToWIP() public {
        vm.prank(alice);
        wip.deposit{ value: 7 ether }();
        vm.prank(alice);
        wip.approve(address(wdata), 7 ether);

        vm.prank(alice);
        wdata.migrate(7 ether);

        assertEq(wdata.balanceOf(address(wip)), 0);
        assertEq(wdata.totalSupply(), 7 ether);
    }

    function test_Receive_FromNonWIP_StillMints() public {
        vm.prank(alice);
        (bool ok, ) = address(wdata).call{ value: 1 ether }("");
        assertTrue(ok);
        assertEq(wdata.balanceOf(alice), 1 ether);
    }

    function testFuzz_Migrate_PreservesUserValue(uint96 wipAmount, uint96 migrateAmount) public {
        vm.assume(wipAmount > 0);
        uint256 wAmt = uint256(wipAmount);
        uint256 mAmt = bound(uint256(migrateAmount), 0, wAmt);

        vm.deal(alice, wAmt);
        vm.prank(alice);
        wip.deposit{ value: wAmt }();

        vm.prank(alice);
        wip.approve(address(wdata), mAmt);

        vm.prank(alice);
        wdata.migrate(mAmt);

        assertEq(wip.balanceOf(alice) + wdata.balanceOf(alice), wAmt);
        assertEq(wdata.balanceOf(alice), mAmt);
        assertEq(address(wdata).balance, mAmt);
    }
}

contract RejectingReceiver {
    receive() external payable {
        revert("nope");
    }
}
