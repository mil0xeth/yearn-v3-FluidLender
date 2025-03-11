// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {UniswapV3Swapper} from "@periphery/swappers/UniswapV3Swapper.sol";
import {Base4626Compounder, ERC20, SafeERC20} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";
import {IFluidVault} from "./interfaces/Fluid/IFluidVault.sol";
import {IAuction} from "./interfaces/IAuction.sol";

contract FluidLender is Base4626Compounder, UniswapV3Swapper {
    using SafeERC20 for ERC20;

    // Array to keep track of reward tokens
    address[] public rewardTokens;

    // Mapping to track reward tokens and their minimum amounts to sell
    mapping(address => uint256) public minAmountToSellMapping;

    enum SwapType {
        NULL,
        UNISWAP_V3,
        AUCTION
    }

    // Mapping to track swap type for each token
    mapping(address => SwapType) public swapType;

    // Address of the auction contract
    address public auction;

    constructor(
        address _asset,
        string memory _name,
        address _fluidVault,
        address _base
    ) Base4626Compounder(_asset, _name, _fluidVault) {
        require(_base != address(0), "!base");
        base = _base;
    }

    /*//////////////////////////////////////////////////////////////
                    REWARD TOKEN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new reward token to be managed by the strategy
     * @param _token Address of the reward token
     * @param _swapType Type of swap to use for this token
     */
    function addRewardToken(
        address _token,
        SwapType _swapType
    ) external onlyManagement {
        require(
            _token != address(asset) && _token != address(vault),
            "cannot be a reward token"
        );
        rewardTokens.push(_token);
        swapType[_token] = _swapType;
    }

    /**
     * @notice Remove a reward token from the strategy
     * @param _token Address of the reward token to remove
     */
    function removeRewardToken(address _token) external onlyManagement {
        address[] memory _rewardTokens = rewardTokens;
        uint256 _length = _rewardTokens.length;

        for (uint256 i = 0; i < _length; i++) {
            if (_rewardTokens[i] == _token) {
                rewardTokens[i] = _rewardTokens[_length - 1];
                rewardTokens.pop();
                delete swapType[_token];
                delete minAmountToSellMapping[_token];
                break;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    SETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the auction contract address
     * @param _auction Address of the auction contract
     */
    function setAuction(address _auction) external onlyManagement {
        if (_auction != address(0)) {
            require(IAuction(_auction).want() == address(asset), "wrong want");
            require(
                IAuction(_auction).receiver() == address(this),
                "wrong receiver"
            );
        }
        auction = _auction;
    }

    /**
     * @notice Set Uniswap V3 pool fees for token pairs
     * @param _token0 First token in the pair
     * @param _token1 Second token in the pair
     * @param _fee Fee tier for the pool
     */
    function setUniFees(
        address _token0,
        address _token1,
        uint24 _fee
    ) external onlyManagement {
        _setUniFees(_token0, _token1, _fee);
    }

    /**
     * @notice Set the swap type for a specific token
     * @param _from Token address to set swap type for
     * @param _swapType Type of swap to use
     */
    function setSwapType(
        address _from,
        SwapType _swapType
    ) external onlyManagement {
        swapType[_from] = _swapType;
    }

    /**
     * @notice Set minimum amount required to sell for a reward token
     * @param _token The reward token address
     * @param _amount Minimum amount required to trigger a sale
     */
    function setMinAmountToSellMapping(
        address _token,
        uint256 _amount
    ) external onlyManagement {
        minAmountToSellMapping[_token] = _amount;
    }

    /**
     * @notice Swap the base token between asset and WETH
     */
    function swapBase() external onlyManagement {
        base = base == address(asset) ? 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 : address(asset);
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL REWARD HANDLING
    //////////////////////////////////////////////////////////////*/


    function _claimAndSellRewards() internal override {
        address[] memory _rewardTokens = rewardTokens;
        uint256 _length = _rewardTokens.length;

        for (uint256 i = 0; i < _length; i++) {
            address token = _rewardTokens[i];
            SwapType _swapType = swapType[token];
            uint256 balance = ERC20(token).balanceOf(address(this));

            if (balance > minAmountToSellMapping[token]) {
                if (_swapType == SwapType.UNISWAP_V3) {
                    _swapFrom(token, address(asset), balance, 0);
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    AUCTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Kick off an auction for a specific token
     * @param _token Token to auction
     * @return Auction ID or other relevant data from the kick
     */
    function kickAuction(
        address _token
    ) external onlyKeepers returns (uint256) {
        require(swapType[_token] == SwapType.AUCTION, "!auction");
        return _kickAuction(_token);
    }

    /**
     * @dev Internal function to kick off an auction
     * @param _from Token to auction
     */
    function _kickAuction(address _from) internal virtual returns (uint256) {
        require(
            _from != address(asset) && _from != address(vault),
            "cannot kick"
        );
        uint256 _balance = ERC20(_from).balanceOf(address(this));
        ERC20(_from).safeTransfer(auction, _balance);
        return IAuction(auction).kick(_from);
    }
}