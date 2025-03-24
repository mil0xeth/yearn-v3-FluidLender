pragma solidity ^0.8.18;

import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";

contract ShutdownTest is Setup {
    function setUp() public virtual override {
        super.setUp(); // Call the setup function from the parent contract
    }

    function test_shutdownCanWithdraw(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount); // Ensure the amount is within valid bounds

        // Deposit the specified amount into the strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);
        assertEq(strategy.totalAssets(), _amount, "!totalAssets"); // Verify total assets match the deposited amount

        // Simulate earning interest over a day
        skip(1 days);

        // Initiate the shutdown process for the strategy
        vm.prank(emergencyAdmin);
        strategy.shutdownStrategy();

        // Check the balance of the fluid liquidity proxy where funds are deposited
        uint256 proxyBalance = asset.balanceOf(FLUID_PROXY);
        assertGe(proxyBalance + 10, _amount, "!_amount"); // Ensure proxy balance is sufficient
        assertEq(strategy.totalAssets(), _amount, "!totalAssets"); // Confirm total assets remain unchanged

        // Store the user's balance before withdrawal
        uint256 balanceBefore = asset.balanceOf(user);

        // Verify the strategy's vault balance
        uint256 vaultBalance = strategy.balanceOfVault();

        // Determine the maximum redeemable amount from the vault
        uint256 maxRedeem = IStrategyInterface(vault).maxRedeem(vault);

        // If the strategy vault balance exceeds the maximum redeemable amount, loop to redeem shares
        if (vaultBalance > maxRedeem) {
            // Continue redeeming until all strategy shares are redeemed
            while (strategy.balanceOf(user) > 0) {
                uint256 toRedeem = strategy.maxRedeem(user); // Get the maximum redeemable amount for the user

                // Adjust to redeem only what the user holds if it's more than the strategy's balance
                if (toRedeem > strategy.balanceOf(user)) {
                    toRedeem = strategy.balanceOf(user);
                }

                // Prank the user and redeem the calculated amount
                vm.prank(user);
                strategy.redeem(toRedeem, user, user);

                // Simulate a day passing for potential interest expansion
                skip(1 days);
            }
        } else {
            assertGe(maxRedeem, vaultBalance, "!maxRedeem"); // Ensure we can redeem our staked balance
            // Withdraw the full amount from the strategy
            vm.prank(user);
            strategy.redeem(_amount, user, user);
        }

        // Verify the user's final balance includes the withdrawn amount
        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }

    function test_emergencyWithdraw_maxUint(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount); // Ensure the amount is within valid bounds

        // Deposit the specified amount into the strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);
        assertEq(strategy.totalAssets(), _amount, "!totalAssets"); // Verify total assets match the deposited amount

        // Simulate earning interest over a day
        skip(1 days);

        // Initiate the shutdown process for the strategy
        vm.prank(emergencyAdmin);
        strategy.shutdownStrategy();

        assertEq(strategy.totalAssets(), _amount, "!totalAssets"); // Confirm total assets remain unchanged

        // Check the balance of the fluid liquidity proxy where funds are deposited
        uint256 proxyBalance = asset.balanceOf(FLUID_PROXY);
        assertGe(proxyBalance + 10, _amount, "!_amount"); // Ensure proxy balance is sufficient

        // Attempt to perform an emergency withdrawal of the maximum uint256 value
        vm.prank(emergencyAdmin);
        strategy.emergencyWithdraw(type(uint256).max); // Should not revert

        // Store the user's balance before withdrawal
        uint256 balanceBefore = asset.balanceOf(user);

        // Verify the strategy's vault balance
        uint256 vaultBalance = strategy.balanceOfVault();

        // Determine the maximum redeemable amount from the vault
        uint256 maxRedeem = IStrategyInterface(vault).maxRedeem(vault);

        // If the strategy vault balance exceeds the maximum redeemable amount, loop to redeem shares
        if (vaultBalance > maxRedeem) {
            // Continue redeeming until all strategy shares are redeemed
            while (strategy.balanceOf(user) > 0) {
                uint256 toRedeem = strategy.maxRedeem(user); // Get the maximum redeemable amount for the user

                // Adjust to redeem only what the user holds if it's more than the strategy's balance
                if (toRedeem > strategy.balanceOf(user)) {
                    toRedeem = strategy.balanceOf(user);
                }

                // Prank the user and redeem the calculated amount
                vm.prank(user);
                strategy.redeem(toRedeem, user, user);

                // Simulate a day passing for potential interest expansion
                skip(1 days);
            }
        } else {
            assertGe(maxRedeem, vaultBalance, "!maxRedeem"); // Ensure we can redeem our staked balance
            // Withdraw the full amount from the strategy  
            vm.prank(user);
            strategy.redeem(_amount, user, user);
        }

        // Verify the user's final balance includes the withdrawn amount
        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }
}