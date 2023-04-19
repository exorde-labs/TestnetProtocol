// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

interface IParametersManager {
    function getStakeManager() external view returns (address);

    function getRepManager() external view returns (address);

    function getReputationSystem() external view returns (address);

    function getAddressManager() external view returns (address);

    function getRewardManager() external view returns (address);

    function getArchivingSystem() external view returns (address);

    function getSpottingSystem() external view returns (address);

    function getComplianceSystem() external view returns (address);

    function getIndexingSystem() external view returns (address);

    function getsFuelSystem() external view returns (address);

    function getExordeToken() external view returns (address);

    function get_MAX_UPDATE_ITERATIONS() external view returns (uint256);
}
