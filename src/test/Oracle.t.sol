// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {StrategyAprOracle} from "../periphery/StrategyAprOracle.sol";
import {FluidLender} from "../FluidLender.sol";
import {Setup} from "./utils/Setup.sol";

contract OracleTest is Setup {
    address[] public rewardTokens;

    // APR Oracle instance
    StrategyAprOracle public oracle;

    function setUp() public override {
        super.setUp();
        oracle = new StrategyAprOracle(management);
        rewardTokens = [FLUID];
        console.log("Oracle deployed at address:", address(oracle));
        console.log("Default reward token (FLUID):", FLUID);
    }

    function test_apr() public {
        uint256 _amount = 1000e6;
        mintAndDepositIntoStrategy(strategy, user, _amount);
        //vm.prank(management);
        //strategy.addRewardToken(FLUID, 1);
        vm.prank(management);
        strategy.setUniFees(FLUID, WETH, 3000);
        vm.prank(management);
        strategy.setUniFees(WETH, address(asset), 500);
        // Call the APR calculation function
        uint256 apr = oracle.aprAfterDebtChange(address(strategy), 0);
        console.log("Calculated APR:", apr);
    }

    function check_oracle(
        address _strategy
    ) internal {
        uint256 _amount = 10000e6;
        mintAndDepositIntoStrategy(strategy, user, _amount);

        uint256 currentApr = oracle.aprAfterDebtChange(_strategy, 0);
        console.log("Current APR:", currentApr);
        assertGt(currentApr, 0);
        // If APR is expected to be under 100%
        assertLt(currentApr, 1e18);

        uint256 newApr = oracle.aprAfterDebtChange(_strategy, 1_000e6);

        assertLt(newApr, currentApr, "!newApr");

        uint256 higherApr = oracle.aprAfterDebtChange(_strategy, -1_000e6);

        assertGt(higherApr, currentApr, "!higherApr");
    }

    function test_oracle() public {
        check_oracle(address(strategy));
    }

}