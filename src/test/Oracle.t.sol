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

    // List of strategies to check for campaigns
    address[] public strategies;

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
        vm.prank(management);
        strategy.addRewardToken(FLUID, 1);
        vm.prank(management);
        strategy.setUniFees(FLUID, WETH, 3000);
        vm.prank(management);
        strategy.setUniFees(WETH, address(asset), 500);
        // Call the APR calculation function
        uint256 apr = oracle.aprAfterDebtChange(address(strategy), 0);
        console.log("Calculated APR:", apr);
    }
/*
    function test_oracle(uint256 _amount, uint16 _percentChange) public {
        _amount = bound(_amount, minFuzzAmount * 100, maxFuzzAmount);
        _percentChange = uint16(
            bound(uint256(_percentChange), 10, MAX_BPS - 1)
        );
        uint256 _delta = (_amount * _percentChange) / MAX_BPS;

        mintAndDepositIntoStrategy(strategy, user, _amount);
        checkOracle(address(strategy), _delta);
    }
*/
}