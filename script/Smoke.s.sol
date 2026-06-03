// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { WDATA } from "../src/WDATA.sol";

/// @notice Smoke test against the live WDATA deployment. Sends real transactions.
/// @dev Deposits a small amount of native DATA, verifies the mint, then withdraws it
///      back so the broadcasting account's WDATA balance is left unchanged (minus gas).
///      Run with:
///        forge script script/Smoke.s.sol:Smoke \
///          --rpc-url https://aeneid.storyrpc.io \
///          --account aeneid --broadcast --legacy --with-gas-price 1gwei
///      Override the target via WDATA_ADDRESS and the amount (wei) via SMOKE_AMOUNT.
contract Smoke is Script {
    address internal constant DEFAULT_WDATA = 0xD18a56346227f25D1410F98f78234305660bB877;
    uint256 internal constant DEFAULT_AMOUNT = 0.001 ether;

    /// @dev Native IP held back to cover gas for the deposit + withdraw txs. Override via SMOKE_GAS_RESERVE.
    uint256 internal constant DEFAULT_GAS_RESERVE = 0.01 ether;

    function run() external {
        WDATA wdata = WDATA(payable(vm.envOr("WDATA_ADDRESS", DEFAULT_WDATA)));
        uint256 amount = vm.envOr("SMOKE_AMOUNT", DEFAULT_AMOUNT);
        uint256 reserve = vm.envOr("SMOKE_GAS_RESERVE", DEFAULT_GAS_RESERVE);

        require(address(wdata).code.length != 0, "Smoke: no code at WDATA address");
        require(keccak256(bytes(wdata.symbol())) == keccak256(bytes("WDATA")), "Smoke: unexpected symbol");

        // Resolve the real broadcasting account. Outside a broadcast `msg.sender` is Foundry's
        // default sender (with a fake infinite balance), not the --account/--sender wallet that
        // actually signs and funds the txs, so read it from the active broadcast instead.
        vm.startBroadcast();
        (, address sender, ) = vm.readCallers();

        uint256 needed = amount + reserve;
        if (sender.balance < needed) {
            console2.log("WDATA:", address(wdata));
            console2.log("sender:", sender);
            console2.log("balance (wei):", sender.balance);
            console2.log("needed (wei):", needed);
            console2.log("  = deposit", amount, "+ gas reserve", reserve);
            console2.log("Sender has no/low test IP. Refill it at the Story Aeneid faucet, then re-run:");
            console2.log("  https://aeneid.faucet.story.foundation");
            revert("Smoke: sender underfunded - refill the faucet");
        }

        console2.log("WDATA:", address(wdata));
        console2.log("sender:", sender);
        console2.log("balance (wei):", sender.balance);
        console2.log("amount (wei):", amount);

        uint256 balBefore = wdata.balanceOf(sender);

        wdata.deposit{ value: amount }();
        require(wdata.balanceOf(sender) == balBefore + amount, "Smoke: deposit did not mint");

        wdata.withdraw(amount);
        require(wdata.balanceOf(sender) == balBefore, "Smoke: withdraw did not burn");

        vm.stopBroadcast();

        console2.log("Smoke OK: deposit + withdraw round-trip succeeded");
    }
}
