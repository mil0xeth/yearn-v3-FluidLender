// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import "forge-std/console.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";

import {AuctionFactory, Auction} from "@periphery/Auctions/AuctionFactory.sol";

contract OperationTest is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_operation() public {
        uint256 _amount = 1000 * 10 ** asset.decimals();

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(strategy.profitMaxUnlockTime());

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        console.log("Profit: ", profit);
        uint256 apr = 100 * profit * 365 * 86400 * 1e18 / (_amount * strategy.profitMaxUnlockTime());
        console.log("APR:", apr);

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_operation_fuzzed(uint256 _amount) public {
        // Bound the amount to reasonable values
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(strategy.profitMaxUnlockTime());

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();
        console.log("Profit: ", profit);

        uint256 apr = 100 * profit * 365 * 86400 * 1e18 / (_amount * strategy.profitMaxUnlockTime());
        console.log("APR:", apr);

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_operation_with_fluid_reward() public {
        uint256 _amount = 1_000_000 * 10 ** asset.decimals();
        uint256 fluidReward = 1000e18;

        // Set up FLUID token and Uniswap fees
        vm.prank(management);
        strategy.addRewardToken(FLUID, 1);
        vm.prank(management);
        strategy.setUniFees(FLUID, WETH, 3000);
        vm.prank(management);
        strategy.setUniFees(WETH, address(asset), 500);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Skip some time and airdrop FLUID rewards
        skip(5 days);
        airdropFromWhale(ERC20(FLUID), address(strategy), fluidReward);
 
        // Verify FLUID balance
        assertEq(ERC20(FLUID).balanceOf(address(strategy)), fluidReward, "!fluid balance");

        // Report profit (this should trigger the FLUID swap)
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Verify FLUID was swapped
        assertEq(ERC20(FLUID).balanceOf(address(strategy)), 0, "!fluid swapped");

        // Calculate and log APR including rewards
        uint256 apr = (100 * profit * 365 * 86400) * 1e18 / (_amount * strategy.profitMaxUnlockTime());
        console.log("Profit including FLUID rewards: ", profit);
        console.log("APR including rewards:", apr);

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_operation_fuzzed_with_fluid_reward(uint256 _amount, uint256 _fluidReward) public {
        // Bound the amounts to reasonable values
        _amount = bound(_amount, 5000e6, maxFuzzAmount);
        _fluidReward = bound(_fluidReward, 100e18, 1000e18);

        // Set up FLUID token and Uniswap fees
        vm.prank(management);
        strategy.addRewardToken(FLUID, 1);
        vm.prank(management);
        strategy.setUniFees(FLUID, WETH, 3000);
        vm.prank(management);
        strategy.setUniFees(WETH, address(asset), 500);

        vm.prank(management);
        strategy.setProfitLimitRatio(65_535);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Skip some time and airdrop FLUID rewards
        skip(5 days);
        airdropFromWhale(ERC20(FLUID), address(strategy), _fluidReward);
 
        // Verify FLUID balance
        assertEq(ERC20(FLUID).balanceOf(address(strategy)), _fluidReward, "!fluid balance");

        // Report profit (this should trigger the FLUID swap)
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Verify FLUID was swapped
        assertEq(ERC20(FLUID).balanceOf(address(strategy)), 0, "!fluid swapped");

        // Calculate and log APR including rewards
        uint256 apr = (100 * profit * 365 * 86400) * 1e18 / (_amount * strategy.profitMaxUnlockTime());
        console.log("Profit including FLUID rewards: ", profit);
        console.log("APR including rewards:", apr);

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }
}
