// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { CREATE3 } from "solady/src/utils/CREATE3.sol";
import { WDATA } from "../src/WDATA.sol";
import { Create3 } from "../src/deploy/Create3.sol";
import { Deploy } from "../script/Deploy.s.sol";

contract DeployCreate3Test is Test {
    Create3 internal factory;
    bytes32 internal constant SALT = keccak256("WDATA");

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        factory = new Create3();
    }

    // ---------- deterministic factory ----------

    function test_DeployedEqualsPredicted() public {
        address predicted = factory.predictDeterministicAddress(SALT);
        address deployed = factory.deployDeterministic(type(WDATA).creationCode, SALT);

        assertEq(deployed, predicted);
        assertGt(deployed.code.length, 0);

        WDATA wdata = WDATA(payable(deployed));
        assertEq(wdata.name(), "Wrapped DATA");
        assertEq(wdata.symbol(), "WDATA");
    }

    function test_Prediction_IndependentOfChainState() public {
        address p1 = factory.predictDeterministicAddress(SALT);
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 100);
        address p2 = factory.predictDeterministicAddress(SALT);
        assertEq(p1, p2);
    }

    function test_Redeploy_Reverts() public {
        factory.deployDeterministic(type(WDATA).creationCode, SALT);
        vm.expectRevert(CREATE3.DeploymentFailed.selector);
        factory.deployDeterministic(type(WDATA).creationCode, SALT);
    }

    function test_SenderNamespaced_DifferByDeployer() public view {
        address a = factory.getDeployed(alice, SALT);
        address b = factory.getDeployed(bob, SALT);
        assertTrue(a != b);
    }

    function test_NamespacedDeploy_MatchesGetDeployed() public {
        address predicted = factory.getDeployed(alice, SALT);
        vm.prank(alice);
        address deployed = factory.deploy(SALT, type(WDATA).creationCode);
        assertEq(deployed, predicted);
    }

    // ---------- deploy script ----------

    function test_Script_DeploysDeterministically() public {
        vm.setEnv("CREATE3_FACTORY", vm.toString(address(factory)));

        Deploy script = new Deploy();
        WDATA first = script.run();

        assertGt(address(first).code.length, 0);
        assertEq(first.symbol(), "WDATA");
        assertEq(address(first), factory.predictDeterministicAddress(SALT));

        // Re-running is idempotent: same factory, same salt, returns the existing deployment.
        WDATA second = script.run();
        assertEq(address(second), address(first));
    }
}
