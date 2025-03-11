// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";
import {IUniswapV3Swapper} from "@periphery/swappers/interfaces/IUniswapV3Swapper.sol";
import {IFluidVault} from "./Fluid/IFluidVault.sol";

interface IStrategyInterface is IStrategy, IUniswapV3Swapper {
    function vault() external view returns (address);
    
    function setUniFees(
        address _token0,
        address _token1,
        uint24 _fee
    ) external;

    function setMinAmountToSellMapping(
        address _token,
        uint256 _amount
    ) external;

    function setSwapType(
        address _from,
        uint8 _swapType
    ) external;

    function addRewardToken(
        address _token,
        uint8 _swapType
    ) external;

    function removeRewardToken(address _token) external;

    function setAuction(address _auction) external;

    function kickAuction(address _token) external returns (uint256);

    function swapBase() external;

    function getUniFees(address token0, address token1) external view returns (uint24);

    function getSwapType(address token) external view returns (bool);

    function getMinAmountToSellMapping(address token) external view returns (uint256);

    function auction() external view returns (address);

    function setProfitLimitRatio(uint256 _newProfitLimitRatio) external;
}
