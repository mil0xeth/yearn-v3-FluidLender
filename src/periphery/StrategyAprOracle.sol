// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";
import {IStrategyInterface} from "../interfaces/IStrategyInterface.sol";
import {IFToken, IFluidLendingResolver, FluidResolverLib} from "../interfaces/IFluidLendingResolver.sol";
import {UniswapV3SwapSimulator, ISwapRouter} from "../libraries/UniswapV3SwapSimulator.sol";

contract StrategyAprOracle is AprOracleBase {
    /// @notice The Uniswap V3 Router contract address used for swap simulations
    address private constant UNISWAP_V3_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;
    /// @notice The Wrapped Ether contract address
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    /// @notice The Fluid Lending Resolver contract address
    IFluidLendingResolver resolver = IFluidLendingResolver(0x2c1Ea8eD86DB491e9875B5061c20872dC0B52c46);
    /// @notice Rate precision for Fluid rewards (1e12 = 1%)
    uint256 private constant RATE_PRECISION = 1e12;

    constructor(address _governance) AprOracleBase("Fluid Strategy APR Oracle", _governance) {}

    /**
     * @notice Will return the expected APR of a Strategy post a supply change.
     * @param _strategy The strategy to get the apr for.
     * @param _delta The difference in supply.
     * @return _apr The expected apr for the vault represented as 1e18.
     */
    function aprAfterDebtChange(
        address _strategy,
        int256 _delta
    ) external view override returns (uint256 _apr) {
        IStrategyInterface _fluidStrategy = IStrategyInterface(_strategy);
        address _fluidVault = _fluidStrategy.vault();
        uint256 _strategyTotalAssets = _fluidStrategy.totalAssets();

        if (int256(_strategyTotalAssets) <= -_delta) return 0;

        // Calculate total assets with delta for APR calculation
        uint256 totalAssetsWithDelta = uint256(int256(_strategyTotalAssets) + _delta);
        
        address _asset = _fluidStrategy.asset();

        _apr += _getLendingApr(_fluidVault, _fluidStrategy);
        console.log("Lending APR:", _apr);
        
        _apr += _getLendingRewardsApr(_fluidVault);
        console.log("Lending Rewards APR:", _apr);

        _apr += _getMerkleRewardsApr(_fluidVault);
        console.log("Merkle Rewards APR:", _apr);

        console.log("Strategy APR:", _apr);
    }


    function _getLendingApr(
        address _fluidVault,
        IStrategyInterface _fluidStrategy
    ) private view returns (uint256 apr) {
        //To do: Implement lending APR calculation
    }

    function _getLendingRewardsApr(
        address _fluidVault
    ) private view returns (uint256 apr) {
        // 2. Add Lending Rewards APR from FluidLendingResolver
        IFToken fToken = IFToken(_fluidVault);
        (,uint256 rewardsRate) = resolver.getFTokenRewards(fToken);
        if (rewardsRate > 0) {
            // Convert rewardsRate from RATE_PRECISION (1e12) to 1e18
            apr += rewardsRate * (1e16 / RATE_PRECISION);
        }
    }

    function _getMerkleRewardsApr(
        address _fluidVault
    ) private view returns (uint256 apr) {
        //To do: Implement merkle rewards APR calculation
    }
  
   
    /// @notice Convert an amount of reward tokens to the equivalent value in a target asset
    /// @param _rewardAmount Amount of reward tokens to convert
    /// @param _rewardToken Address of the reward token
    /// @param _asset Target asset address to convert to
    /// @param _rewardWethFee Uniswap V3 fee tier for reward/WETH pool
    /// @param _wethAssetFee Uniswap V3 fee tier for WETH/asset pool
    /// @return _assetAmount The equivalent amount in the target asset
    function rewardInAsset(
        uint256 _rewardAmount,
        address _rewardToken,
        address _asset,
        uint24 _rewardWethFee,
        uint24 _wethAssetFee
    ) private view returns (uint256 _assetAmount) {
        if (_rewardAmount == 0 || _rewardToken == address(0)) {
            return 0;
        }

        uint256 _wethAmount = UniswapV3SwapSimulator.simulateExactInputSingle(
            ISwapRouter(UNISWAP_V3_ROUTER),
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _rewardToken,
                tokenOut: WETH,
                fee: _rewardWethFee,
                recipient: address(0),
                deadline: block.timestamp,
                amountIn: _rewardAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        if (_asset == WETH || _wethAssetFee == 0) return _wethAmount;

        _assetAmount = UniswapV3SwapSimulator.simulateExactInputSingle(
            ISwapRouter(UNISWAP_V3_ROUTER),
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: _asset,
                fee: _wethAssetFee,
                recipient: address(0),
                deadline: block.timestamp,
                amountIn: _wethAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

}