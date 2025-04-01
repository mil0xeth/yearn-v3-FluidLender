// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;
import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";
import {IStrategyInterface} from "../interfaces/IStrategyInterface.sol";
import {IFToken, IFluidLendingResolver, FluidResolverLib, IFluidLiquidityResolver} from "../interfaces/IFluidLendingResolver.sol";
import {UniswapV3SwapSimulator, ISwapRouter} from "../libraries/UniswapV3SwapSimulator.sol";

contract StrategyAprOracle is AprOracleBase {
    address private constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IFluidLendingResolver resolver = IFluidLendingResolver(0x2c1Ea8eD86DB491e9875B5061c20872dC0B52c46);
    IFluidLiquidityResolver liquidityResolver = IFluidLiquidityResolver(0xF82111c4354622AB12b9803cD3F6164FCE52e847);

    /// @notice Rate precision for Fluid rewards (1e12 = 1%)
    uint256 private constant RATE_PRECISION = 1e12;

    uint256 public merkleApr = 27500000000000000;

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
        
        // Use only the new lending APR function that properly follows Fluid's calculation
        _apr = _getLendingApr(_fluidVault, _fluidStrategy, _delta, totalAssetsWithDelta);
        
        // Add lending rewards APR
        _apr += _getLendingRewardsApr(_fluidVault);

        // Add merkle rewards APR
        _apr += _getMerkleRewardsApr(_delta, totalAssetsWithDelta);
    }

    function _getLendingApr(
        address _fluidVault,
        IStrategyInterface _fluidStrategy,
        int256 _delta,
        uint256 _totalAssetsWithDelta
    ) private view returns (uint256 apr) {
        address asset = _fluidStrategy.asset();
        FluidResolverLib.OverallTokenData memory overallTokenData = liquidityResolver.getOverallTokenData(asset);
        apr = overallTokenData.supplyRate * 1e14;
    }

    function _getLendingRewardsApr(
        address _fluidVault
    ) private view returns (uint256 apr) {
        // Get lending rewards APR from FluidLendingResolver
        IFToken fToken = IFToken(_fluidVault);
        (,uint256 rewardsRate) = resolver.getFTokenRewards(fToken);
        
        // Only process if there are rewards
        if (rewardsRate > 0) {
            // Convert rewardsRate from RATE_PRECISION (1e12) to 1e18
            // Be careful to avoid miscalculation here
            apr = (rewardsRate * 1e18) / RATE_PRECISION;
        }
    }

    function _getMerkleRewardsApr(
        int256 _delta,
        uint256 _totalAssetsWithDelta
    ) private view returns (uint256 apr) {
        // Skip calculation if total assets is zero
        if (_totalAssetsWithDelta == 0) return 0;

        uint256 baseApr = merkleApr;

        if (baseApr == 0) return 0;
        
        // The total merkle rewards are fixed for the program period
        // When assets change, the APR per unit of asset changes inversely
        
        // Calculate original total assets before delta
        uint256 originalTotalAssets;
        if (_delta < 0) {
            // For negative delta (withdrawal), we add the absolute value
            originalTotalAssets = _totalAssetsWithDelta + uint256(-_delta);
        } else {
            // For positive delta (deposit), we subtract
            originalTotalAssets = _totalAssetsWithDelta - uint256(_delta);
        }
        
        // If original assets were zero, use the delta as the baseline
        if (originalTotalAssets == 0) {
            // For first deposit, just return the base APR
            return baseApr;
        }
        
        // Calculate adjusted APR based on asset changes
        // Fixed rewards distributed across changing asset base
        apr = (merkleApr * originalTotalAssets) / _totalAssetsWithDelta;
        
        return apr;
    }
  
    /// @notice Set the merkle APR
    /// @param _merkleApr The merkle APR to set
    /// @dev Use the API to set the merkle APR: https://api.fluid.instadapp.io/1/tokens/0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33
    function setMerkleApr(uint256 _merkleApr) external onlyGovernance {
        merkleApr = _merkleApr;
        merkleApr = _merkleApr;
    }
}