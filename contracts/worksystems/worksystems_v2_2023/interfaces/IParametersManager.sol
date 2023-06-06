// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

interface IParametersManager {
    // -------------- GETTERS : GENERAL --------------------
    function getMaxTotalWorkers() external view returns(uint256);

    function getVoteQuorum() external view returns(uint256);

    function get_MAX_UPDATE_ITERATIONS() external view returns(uint256);

    function get_MAX_CONTRACT_STORED_BATCHES() external view returns(uint256);

    function get_MAX_SUCCEEDING_NOVOTES() external view returns(uint256);

    function get_NOVOTE_REGISTRATION_WAIT_DURATION() external view returns(uint256);

    // -------------- GETTERS : ADDRESSES --------------------
    function getStakeManager() external view returns(address);

    function getRepManager() external view returns(address);

    function getAddressManager() external view returns(address);

    function getReputationSystem() external view returns(address);

    function getRewardManager() external view returns(address);

    function getArchivingSystem() external view returns(address);

    function getSpottingSystem() external view returns(address);

    function getQualitySystem() external view returns(address);

    function getIndexingSystem() external view returns(address);

    function getsFuelSystem() external view returns(address);

    function getExordeToken() external view returns(address);

    // -------------- GETTERS : SPOTTING --------------------
    function get_SPOT_DATA_BATCH_SIZE() external view returns(uint256);

    function get_SPOT_MIN_STAKE() external view returns(uint256);

    function get_SPOT_MIN_CONSENSUS_WORKER_COUNT() external view returns(uint256);

    function get_SPOT_MAX_CONSENSUS_WORKER_COUNT() external view returns(uint256);

    function get_SPOT_COMMIT_ROUND_DURATION() external view returns(uint256);

    function get_SPOT_REVEAL_ROUND_DURATION() external view returns(uint256);

    function get_SPOT_MIN_REP_SpotData() external view returns(uint256);

    function get_SPOT_MIN_REWARD_SpotData() external view returns(uint256);

    function get_SPOT_MIN_REP_DataValidation() external view returns(uint256);

    function get_SPOT_MIN_REWARD_DataValidation() external view returns(uint256);

    function get_SPOT_INTER_ALLOCATION_DURATION() external view returns(uint256);

    function get_SPOT_TOGGLE_ENABLED() external view returns(bool);

    function get_SPOT_TIMEFRAME_DURATION() external view returns(uint256);

    function get_SPOT_GLOBAL_MAX_SPOT_PER_PERIOD() external view returns(uint256);

    function get_SPOT_MAX_SPOT_PER_USER_PER_PERIOD() external view returns(uint256);

    function get_SPOT_NB_TIMEFRAMES() external view returns(uint256);

    // -------------- GETTERS : QUALITY --------------------
    function get_QUALITY_DATA_BATCH_SIZE() external view returns(uint256);

    function get_QUALITY_MIN_STAKE() external view returns(uint256);

    function get_QUALITY_MIN_CONSENSUS_WORKER_COUNT() external view returns(uint256);

    function get_QUALITY_MAX_CONSENSUS_WORKER_COUNT() external view returns(uint256);

    function get_QUALITY_COMMIT_ROUND_DURATION() external view returns(uint256);

    function get_QUALITY_REVEAL_ROUND_DURATION() external view returns(uint256);

    function get_QUALITY_MIN_REP_SpotData() external view returns(uint256);

    function get_QUALITY_MIN_REWARD_SpotData() external view returns(uint256);

    function get_QUALITY_MIN_REP_DataValidation() external view returns(uint256);

    function get_QUALITY_MIN_REWARD_DataValidation() external view returns(uint256);

    function get_QUALITY_INTER_ALLOCATION_DURATION() external view returns(uint256);

    function get_QUALITY_TOGGLE_ENABLED() external view returns(bool);

    function get_QUALITY_TIMEFRAME_DURATION() external view returns(uint256);

    function get_QUALITY_GLOBAL_MAX_QUALITY_PER_PERIOD() external view returns(uint256);

    function get_QUALITY_MAX_QUALITY_PER_USER_PER_PERIOD() external view returns(uint256);

    function get_QUALITY_NB_TIMEFRAMES() external view returns(uint256);

    // -------------- GETTERS : ARCHIVE --------------------
    function get_ARCHIVING_DATA_BATCH_SIZE() external view returns(uint256);

    function get_ARCHIVING_MIN_STAKE() external view returns(uint256);

    function get_ARCHIVING_MIN_CONSENSUS_WORKER_COUNT() external view returns(uint256);

    function get_ARCHIVING_MAX_CONSENSUS_WORKER_COUNT() external view returns(uint256);

    function get_ARCHIVING_COMMIT_ROUND_DURATION() external view returns(uint256);

    function get_ARCHIVING_REVEAL_ROUND_DURATION() external view returns(uint256);

    function get_ARCHIVING_MIN_REP_SpotData() external view returns(uint256);

    function get_ARCHIVING_MIN_REWARD_SpotData() external view returns(uint256);

    function get_ARCHIVING_MIN_REP_DataValidation() external view returns(uint256);

    function get_ARCHIVING_MIN_REWARD_DataValidation() external view returns(uint256);

    function get_ARCHIVING_INTER_ALLOCATION_DURATION() external view returns(uint256);

    function get_ARCHIVING_TOGGLE_ENABLED() external view returns(bool);

    function get_ARCHIVING_TIMEFRAME_DURATION() external view returns(uint256);

    function get_ARCHIVING_GLOBAL_MAX_ARCHIVING_PER_PERIOD() external view returns(uint256);

    function get_ARCHIVING_MAX_ARCHIVING_PER_USER_PER_PERIOD() external view returns(uint256);

    function get_ARCHIVING_NB_TIMEFRAMES() external view returns(uint256);

}
