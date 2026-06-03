// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { WDATA } from "../src/WDATA.sol";
import { Create3 } from "../src/deploy/Create3.sol";

contract Deploy is Script {
    /// @dev Story Protocol's Create3 genesis predeploy. Override with env CREATE3_FACTORY.
    address internal constant DEFAULT_FACTORY = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;

    /// @dev Salt for WDATA's deterministic address; the address depends only on (factory, salt).
    bytes32 internal constant WDATA_SALT = keccak256("WDATA");

    function run() external returns (WDATA wdata) {
        address factory = vm.envOr("CREATE3_FACTORY", DEFAULT_FACTORY);

        vm.startBroadcast();

        if (factory.code.length == 0) {
            factory = address(new Create3());
            console2.log("Deployed Create3 factory at:", factory);
        }

        address predicted = Create3(factory).predictDeterministicAddress(WDATA_SALT);
        console2.log("WDATA predicted address:", predicted);

        if (predicted.code.length != 0) {
            vm.stopBroadcast();
            console2.log("WDATA already deployed, skipping.");
            return WDATA(payable(predicted));
        }

        address deployed = Create3(factory).deployDeterministic(type(WDATA).creationCode, WDATA_SALT);

        vm.stopBroadcast();

        require(deployed == predicted, "Deploy: address mismatch");
        wdata = WDATA(payable(deployed));
        require(keccak256(bytes(wdata.symbol())) == keccak256(bytes("WDATA")), "Deploy: unexpected symbol");
        console2.log("WDATA deployed at:", deployed);
    }
}
