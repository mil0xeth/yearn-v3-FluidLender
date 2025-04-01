// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import "forge-std/console.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";

import {AuctionFactory, Auction} from "@periphery/Auctions/AuctionFactory.sol";

contract OperationTest is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_operation_low() public {
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
        //console.log("APR:", apr);

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

    function test_operation_fuzzed_capped(uint256 _amount) public {
        // Bound the amount to reasonable values
        _amount = bound(_amount, minFuzzAmount, 1e13);

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

    function test_operation_with_fluid_reward_high() public {
        uint256 _amount = 1_000_000 * 10 ** asset.decimals();
        uint256 fluidReward = 1000e18;

        // Set up FLUID token and Uniswap fees
        //vm.prank(management);
        //strategy.addRewardToken(FLUID, 1);
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

    function test_operation_fuzzed_with_fluid_reward_capped(uint256 _amount, uint256 _fluidReward) public {
        // Bound the amounts to reasonable values
        _amount = bound(_amount, 5000e6,  1e13);
        _fluidReward = bound(_fluidReward, 100e18, 1000e18);

        // Set up FLUID token and Uniswap fees
        //vm.prank(management);
        //strategy.addRewardToken(FLUID, 1);
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

    function test_operation_uncapped(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, 9_950));

        mintAndDepositIntoStrategy(strategy, user, _amount);
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        skip(1 days);
        assertEq(asset.balanceOf(address(strategy)), 0, "!empty");

        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        airdrop(asset, address(strategy), toAirdrop);
        assertEq(asset.balanceOf(address(strategy)), toAirdrop, "!airdrop");

        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        assertGe(profit + 10, toAirdrop, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());
        uint256 balanceBefore = asset.balanceOf(user);

        uint256 vaultBalance = strategy.balanceOfVault();
        uint256 maxRedeem = IStrategyInterface(vault).maxRedeem(vault);
        uint256 proxyBalance = asset.balanceOf(FLUID_PROXY);

        assertGe(proxyBalance + 10, _amount, "!_amount");

        // The loop redeems the user's shares from the strategy until all shares are redeemed.
        if (vaultBalance > maxRedeem) {
            while (strategy.balanceOf(user) > 0) {
                uint256 toRedeem = strategy.maxRedeem(user);
                if (toRedeem > strategy.balanceOf(user)) { toRedeem = strategy.balanceOf(user); }
                vm.prank(user);
                strategy.redeem(toRedeem, user, user);
                skip(1 days);
            }
        } else {
            assertGe(maxRedeem, vaultBalance, "!maxRedeem");
            vm.prank(user);
            strategy.redeem(_amount, user, user);
        }

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }

    function test_operation_fees_uncapped(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, 9_950));

        setFees(0, 1_000);
        mintAndDepositIntoStrategy(strategy, user, _amount);
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        skip(1 days);
        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        airdrop(asset, address(strategy), toAirdrop);

        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        assertGe(profit + 10, toAirdrop, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());
        uint256 expectedShares = (profit * 1_000) / MAX_BPS;
        assertEq(strategy.balanceOf(performanceFeeRecipient), expectedShares);

        uint256 balanceBefore = asset.balanceOf(user);
        uint256 vaultBalance = strategy.balanceOfVault();
        uint256 maxRedeem = IStrategyInterface(vault).maxRedeem(vault);
        uint256 proxyBalance = asset.balanceOf(FLUID_PROXY);

        assertGe(proxyBalance + 10, _amount, "!_amount");

        uint256 toRedeem;
        if (vaultBalance > maxRedeem) {
            while (strategy.balanceOf(user) > 0) {
                toRedeem = strategy.maxRedeem(user);
                if (toRedeem > strategy.balanceOf(user)) { toRedeem = strategy.balanceOf(user); }
                vm.prank(user);
                strategy.redeem(toRedeem, user, user);
                skip(1 days);
            }
        } else {
            assertGe(maxRedeem, vaultBalance, "!maxRedeem");
            vm.prank(user);
            strategy.redeem(_amount, user, user);
        }

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");

        vaultBalance = strategy.balanceOfVault();
        maxRedeem = IStrategyInterface(vault).maxRedeem(vault);

        // The loop redeems the user's shares from the strategy until all shares are redeemed.
        if (vaultBalance > maxRedeem) {
            while (strategy.balanceOf(performanceFeeRecipient) > 0) {
                toRedeem = strategy.maxRedeem(performanceFeeRecipient);
                if (toRedeem > strategy.balanceOf(performanceFeeRecipient)) { toRedeem = strategy.balanceOf(performanceFeeRecipient); }
                vm.prank(performanceFeeRecipient);
                strategy.redeem(toRedeem, performanceFeeRecipient, performanceFeeRecipient);
                skip(1 days);
            }
        } else {
            assertGe(maxRedeem, vaultBalance, "!maxRedeem");
            vm.prank(performanceFeeRecipient);
            strategy.redeem(expectedShares, performanceFeeRecipient, performanceFeeRecipient);
        }
        checkStrategyTotals(strategy, 0, 0, 0);
        assertGe(asset.balanceOf(performanceFeeRecipient), expectedShares, "!perf fee out");
    }
}
