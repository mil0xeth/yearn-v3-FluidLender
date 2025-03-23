// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface IFToken {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToShares(uint256) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function getData() external view returns (
        address liquidity_,
        address lendingFactory_,
        address lendingRewardsRateModel_,
        address permit2_,
        address rebalancer_,
        bool rewardsActive_,
        uint256 liquidityBalance_,
        uint256 liquidityExchangePrice_,
        uint256 tokenExchangePrice_
    );
}

// Library to hold Fluid Lending resolver structs
library FluidResolverLib {
    // Structure to hold the fluid token supply data
    struct UserSupplyData {
        uint256 supply;
        uint256 supplyRate;
        uint256 supplyRewardsRate;
        uint256 collateral;
        uint256 collateralFactor;
        uint256 liquidationFactor;
    }

    // Structure to hold overall token data
    struct OverallTokenData {
        uint256 supply;
        uint256 supplyRate;
        uint256 supplyRewardsRate;
        uint256 borrow;
        uint256 borrowRate;
        uint256 borrowRewardsRate;
        uint256 liquidity;
        uint256 liquidateReward;
        uint256 liquidationFactor;
        uint256 collateralFactor;
    }
}

/// @notice Fluid Lending protocol resolver interface (minimal version)
interface IFluidLendingResolver {
    /// @notice Get details about rewards for a specific fToken
    /// @param fToken_ The fToken to get rewards for
    /// @return rewardsRateModel_ The rewards rate model contract address
    /// @return rewardsRate_ The current rewards rate (with 1e12 precision where 1e12 = 1%)
    function getFTokenRewards(
        IFToken fToken_
    ) external view returns (address rewardsRateModel_, uint256 rewardsRate_);

    /// @notice Get supply data for a user
    /// @param token The token address
    /// @param underlying The underlying asset address
    /// @return userSupplyData The user supply data
    /// @return overallTokenData The overall token data
    function getUserSupplyData(
        address token,
        address underlying
    ) external view returns (
        FluidResolverLib.UserSupplyData memory userSupplyData,
        FluidResolverLib.OverallTokenData memory overallTokenData
    );
    /// @notice Get the configuration details for the rewards rate model of a specific fToken
    /// @param fToken_ The fToken to get the rewards rate model configuration for
    /// @return duration_ The duration of the rewards rate model
    /// @return startTime_ The start time of the rewards rate model
    /// @return endTime_ The end time of the rewards rate model
    /// @return startTvl_ The starting total value locked (TVL) for the rewards rate model
    /// @return maxRate_ The maximum rate for the rewards rate model
    /// @return rewardAmount_ The total reward amount for the rewards rate model
    /// @return initiator_ The address of the initiator for the rewards rate model
    function getFTokenRewardsRateModelConfig(
        IFToken fToken_
    ) external view returns (
        uint256 duration_,
        uint256 startTime_,
        uint256 endTime_,
        uint256 startTvl_,
        uint256 maxRate_,
        uint256 rewardAmount_,
        address initiator_
    );
} 