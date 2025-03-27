// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {FluidLender} from "./FluidLender.sol";
import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";

contract FluidLenderFactory {
    /// @notice Revert message for when a strategy has already been deployed.
    error AlreadyDeployed(address _strategy);

    event NewFluidLender(address indexed strategy, address indexed asset);

    address public management;
    address public performanceFeeRecipient;
    address public keeper;
    address public GOV;

    address public immutable emergencyAdmin;

    /// @notice Track the deployments. asset => strategy
    mapping(address => address) public deployments;

    constructor(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin,
        address _gov
    ) {
        require(_management != address(0), "ZERO ADDRESS");
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
        GOV = _gov;
    }

    /**
     * @notice Deploy a new Fluid Lender Strategy.
     * @dev This will set the msg.sender to all of the permissioned roles. Can only be called by management.
     * @param _asset The underlying asset for the lender to use.
     * @param _name The name for the lender to use.
     * @param _vault The Fluid vault address to use.
     * @param _base The base token address to use.
     * @return The address of the new lender.
     */
    function newFluidLender(
        address _asset,
        string memory _name,
        address _vault,
        address _base
    ) external onlyManagement returns (address) {
        if (deployments[_asset] != address(0))
            revert AlreadyDeployed(deployments[_asset]);
        // We need to use the custom interface with the
        // tokenized strategies available setters.
        IStrategyInterface newStrategy = IStrategyInterface(
            address(new FluidLender(_asset, _name, _vault, _base, GOV))
        );
        newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        newStrategy.setKeeper(keeper);
        newStrategy.setPendingManagement(management);
        newStrategy.setEmergencyAdmin(emergencyAdmin);

        emit NewFluidLender(address(newStrategy), _asset);

        deployments[_asset] = address(newStrategy);
        return address(newStrategy);
    }

    /**
     * @notice Check if a strategy has been deployed by this Factory
     * @param _strategy strategy address
     */
    function isDeployedStrategy(
        address _strategy
    ) external view returns (bool) {
        address _asset = IStrategyInterface(_strategy).asset();
        return deployments[_asset] == _strategy;
    }

    /**
     * @notice Set important addresses for this factory.
     * @dev Can only be called by management
     * @param _management The address to set as the management address.
     * @param _performanceFeeRecipient The address to set as the performance fee recipient address.
     * @param _keeper The address to set as the keeper address.
     */
    function setAddresses(
        address _management,
        address _performanceFeeRecipient,
        address _keeper
    ) external {
        require(msg.sender == management, "!management");
        require(
            _performanceFeeRecipient != address(0) && _management != address(0),
            "ZERO_ADDRESS"
        );
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
    }

    modifier onlyManagement() {
        require(msg.sender == management, "!management");
        _;
    }
}
