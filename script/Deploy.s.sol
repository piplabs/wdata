// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { WDATA } from "../src/WDATA.sol";

contract Deploy is Script {
    function run() external returns (WDATA wdata) {
        address wip = vm.envAddress("WIP_ADDRESS");
        vm.startBroadcast();
        wdata = new WDATA(wip);
        vm.stopBroadcast();
    }
}
