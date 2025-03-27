// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface IMerkleDistributor {
    function claim(address, uint256, uint8, bytes32, uint256, bytes32[] calldata, bytes calldata) external;
}