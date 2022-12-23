// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
@title Parameters  v0.1
@author Mathias Dail
*/
contract Parameters is Ownable {
    // Default values
    //////////////// GENERAL SYSTEM PARAMTERS
    uint256 public MAX_TOTAL_WORKERS = 100000;
    uint256 public VOTE_QUORUM = 50;
    uint256 public MAX_UPDATE_ITERATIONS = 50;
    uint256 public MAX_CONTRACT_STORED_BATCHES = 20000;
    //////////////// SPOTTING RELATED PARAMETERS
    uint256 public SPOT_DATA_BATCH_SIZE = 20;
    uint256 public SPOT_MIN_STAKE = 25 * (10**18);
    uint256 public SPOT_MIN_CONSENSUS_WORKER_COUNT = 7;
    uint256 public SPOT_MAX_CONSENSUS_WORKER_COUNT = 11;
    uint256 public SPOT_COMMIT_ROUND_DURATION = 450;
    uint256 public SPOT_REVEAL_ROUND_DURATION = 150;
    uint256 public SPOT_MIN_REWARD_SpotData = 1 * (10**13);
    uint256 public SPOT_MIN_REP_SpotData = 5 * (10**15);
    uint256 public SPOT_MIN_REWARD_DataValidation = 1 * (10**13);
    uint256 public SPOT_MIN_REP_DataValidation = 20 * (10**15);
    // SPOT DATA LIMITATIONS
    uint256 public SPOT_INTER_ALLOCATION_DURATION = 0;
    bool public SPOT_TOGGLE_ENABLED = true;
    uint256 public SPOT_TIMEFRAME_DURATION = 240;
    uint256 public SPOT_GLOBAL_MAX_SPOT_PER_PERIOD = 3000000;
    uint256 public SPOT_MAX_SPOT_PER_USER_PER_PERIOD = 1000;
    uint256 public SPOT_NB_TIMEFRAMES = 15;
    uint256 public MAX_SUCCEEDING_NOVOTES = 10;
    uint256 public NOVOTE_REGISTRATION_WAIT_DURATION = 30; // in seconds
    //////////////// Compliance RELATED PARAMETERS
    uint256 public COMPLIANCE_DATA_BATCH_SIZE = 1;
    uint256 public COMPLIANCE_MIN_CONSENSUS_WORKER_COUNT = 2;
    uint256 public COMPLIANCE_MAX_CONSENSUS_WORKER_COUNT = 4;
    uint256 public COMPLIANCE_MIN_STAKE = 25 * (10**18);
    uint256 public COMPLIANCE_COMMIT_ROUND_DURATION = 400;
    uint256 public COMPLIANCE_REVEAL_ROUND_DURATION = 180;
    uint256 public COMPLIANCE_MIN_REWARD_DataValidation = 1 * (10**15);
    uint256 public COMPLIANCE_MIN_REP_DataValidation = 10 * (10**15);
    //////////////// Compliance RELATED PARAMETERS
    uint256 public INDEXING_DATA_BATCH_SIZE = 1;
    uint256 public INDEXING_MIN_CONSENSUS_WORKER_COUNT = 2;
    uint256 public INDEXING_MAX_CONSENSUS_WORKER_COUNT = 4;
    uint256 public INDEXING_MIN_STAKE = 25 * (10**18);
    uint256 public INDEXING_COMMIT_ROUND_DURATION = 400;
    uint256 public INDEXING_REVEAL_ROUND_DURATION = 180;
    uint256 public INDEXING_MIN_REWARD_DataValidation = 1 * (10**15);
    uint256 public INDEXING_MIN_REP_DataValidation = 10 * (10**15);
    //////////////// ACHIVING RELATED PARAMETERS
    uint256 public ARCHIVING_DATA_BATCH_SIZE = 1;
    uint256 public ARCHIVING_MIN_CONSENSUS_WORKER_COUNT = 2;
    uint256 public ARCHIVING_MAX_CONSENSUS_WORKER_COUNT = 4;
    uint256 public ARCHIVING_MIN_STAKE = 25 * (10**18);
    uint256 public ARCHIVING_COMMIT_ROUND_DURATION = 400;
    uint256 public ARCHIVING_REVEAL_ROUND_DURATION = 180;
    uint256 public ARCHIVING_MIN_REWARD_DataValidation = 1 * (10**15);
    uint256 public ARCHIVING_MIN_REP_DataValidation = 10 * (10**15);
    //////////////// CONTRACTS
    address public token;
    address public StakeManager;
    address public Reputation;
    address public RepManager;
    address public RewardManager;
    address public AddressManager;
    address public sFuel;

    address public SpottingSystem;
    address public ComplianceSystem;
    address public IndexingSystem;
    address public ArchivingSystem;

    // for other contracts
    // interface IParametersManager {
    //       // -------------- GETTERS : GENERAL --------------------
    //     function getMaxTotalWorkers() external view returns(uint256);
    //     function getVoteQuorum() external view returns(uint256);
    //     function get_MAX_UPDATE_ITERATIONS() external view returns(uint256);
    //     function get_MAX_CONTRACT_STORED_BATCHES() external view returns(uint256);
    //     function get_MAX_SUCCEEDING_NOVOTES() external view returns(uint256);
    //     function get_NOVOTE_REGISTRATION_WAIT_DURATION() external view returns(uint256);
    //     // -------------- GETTERS : ADDRESSES --------------------
    //     function getStakeManager() external view returns(address);
    //     function getRepManager() external view returns(address);
    //     function getReputationSystem() external view returns(address);
    //     function getAddressManager() external view returns(address);
    //     function getRewardManager() external view returns(address);
    //     function getArchivingSystem() external view returns(address);
    //     function getIndexingSystem() external view returns(address);
    //     function getSpottingSystem() external view returns(address);
    //     function getComplianceSystem() external view returns(address);
    //     function getsFuelSystem() external view returns(address);
    //     function getExordeToken() external view returns(address);
    //     // -------------- GETTERS : SPOTTING --------------------
    //     function get_SPOT_DATA_BATCH_SIZE() external view returns(uint256);
    //     function get_SPOT_MIN_STAKE() external view returns(uint256);
    //     function get_SPOT_MIN_CONSENSUS_WORKER_COUNT() external view returns(uint256);
    //     function get_SPOT_MAX_CONSENSUS_WORKER_COUNT() external view returns(uint256);
    //     function get_SPOT_COMMIT_ROUND_DURATION() external view returns(uint256);
    //     function get_SPOT_REVEAL_ROUND_DURATION() external view returns(uint256);
    //     function get_SPOT_MIN_REP_SpotData() external view returns(uint256);
    //     function get_SPOT_MIN_REWARD_SpotData() external view returns(uint256);
    //     function get_SPOT_MIN_REP_DataValidation() external view returns(uint256);
    //     function get_SPOT_MIN_REWARD_DataValidationData() external view returns(uint256);
    //     function get_SPOT_INTER_ALLOCATION_DURATION() external view returns(uint256);
    //     function get_SPOT_TOGGLE_ENABLED() external view returns(bool);
    //     function get_SPOT_TIMEFRAME_DURATION() external view returns(uint256);
    //     function get_SPOT_GLOBAL_MAX_SPOT_PER_PERIOD() external view returns(uint256);
    //     function get_SPOT_MAX_SPOT_PER_USER_PER_PERIOD() external view returns(uint256);
    //     function get_SPOT_NB_TIMEFRAMES() external view returns(uint256);
    //     // -------------- GETTERS : Compliance --------------------
    //     function get_COMPLIANCE_DATA_BATCH_SIZE() external view returns(uint256);
    //     function get_COMPLIANCE_MIN_STAKE() external view returns(uint256);
    //     function get_COMPLIANCE_MIN_CONSENSUS_WORKER_COUNT() external view returns(uint256);
    //     function get_COMPLIANCE_MAX_CONSENSUS_WORKER_COUNT() external view returns(uint256);
    //     function get_COMPLIANCE_COMMIT_ROUND_DURATION() external view returns(uint256);
    //     function get_COMPLIANCE_REVEAL_ROUND_DURATION() external view returns(uint256);
    //     function get_COMPLIANCE_MIN_REWARD_DataValidation() external view returns(uint256);
    //     function get_COMPLIANCE_MIN_REP_DataValidation() external view returns(uint256);
    //     // -------------- GETTERS : Indexing --------------------
    //     function get_INDEXING_DATA_BATCH_SIZE() external view returns(uint256);
    //     function get_INDEXING_MIN_STAKE() external view returns(uint256);
    //     function get_INDEXING_MIN_CONSENSUS_WORKER_COUNT() external view returns(uint256);
    //     function get_INDEXING_MAX_CONSENSUS_WORKER_COUNT() external view returns(uint256);
    //     function get_INDEXING_COMMIT_ROUND_DURATION() external view returns(uint256);
    //     function get_INDEXING_REVEAL_ROUND_DURATION() external view returns(uint256);
    //     function get_INDEXING_MIN_REWARD_DataValidation() external view returns(uint256);
    //     function get_INDEXING_MIN_REP_DataValidation() external view returns(uint256);
    //     // -------------- GETTERS : Archiving --------------------
    //     function get_ARCHIVING_DATA_BATCH_SIZE() external view returns(uint256);
    //     function get_ARCHIVING_MIN_STAKE() external view returns(uint256);
    //     function get_ARCHIVING_MIN_CONSENSUS_WORKER_COUNT() external view returns(uint256);
    //     function get_ARCHIVING_MAX_CONSENSUS_WORKER_COUNT() external view returns(uint256);
    //     function get_ARCHIVING_COMMIT_ROUND_DURATION() external view returns(uint256);
    //     function get_ARCHIVING_REVEAL_ROUND_DURATION() external view returns(uint256);
    //     function get_ARCHIVING_MIN_REWARD_DataValidation() external view returns(uint256);
    //     function get_ARCHIVING_MIN_REP_DataValidation() external view returns(uint256);
    // }
    function destroyContract() public onlyOwner {
        selfdestruct(payable(owner()));
    }

    function updateGeneralParameters(uint256 ParameterIndex, uint256 uintValue) public onlyOwner {
        if (ParameterIndex == 1) {
            MAX_TOTAL_WORKERS = uintValue;
        }
        if (ParameterIndex == 2) {
            VOTE_QUORUM = uintValue;
        }
        if (ParameterIndex == 3) {
            MAX_UPDATE_ITERATIONS = uintValue;
        }
        if (ParameterIndex == 4) {
            MAX_CONTRACT_STORED_BATCHES = uintValue;
        }
    }

    function updateContractsAddresses(
        address StakeManager_,
        address RepManager_,
        address Reputation_,
        address RewardManager_,
        address AddressManager_,
        address SpottingSystem_,
        address ComplianceSystem_,
        address IndexingSystem_,
        address ArchivingSystem_,
        address sFuel_,
        address token_
    ) public onlyOwner {
        if (StakeManager_ != address(0)) {
            StakeManager = StakeManager_;
        }
        if (RepManager_ != address(0)) {
            RepManager = RepManager_;
        }
        if (Reputation_ != address(0)) {
            Reputation = Reputation_;
        }
        if (RewardManager_ != address(0)) {
            RewardManager = RewardManager_;
        }
        if (AddressManager_ != address(0)) {
            AddressManager = AddressManager_;
        }
        if (ComplianceSystem_ != address(0)) {
            ComplianceSystem = ComplianceSystem_;
        }
        if (SpottingSystem_ != address(0)) {
            SpottingSystem = SpottingSystem_;
        }
        if (IndexingSystem_ != address(0)) {
            IndexingSystem = IndexingSystem_;
        }
        if (ArchivingSystem_ != address(0)) {
            ArchivingSystem = ArchivingSystem_;
        }
        if (sFuel_ != address(0)) {
            sFuel = sFuel_;
        }
        if (token_ != address(0)) {
            token = token_;
        }
    }

    function updateSpottingParameters(
        uint256 ParameterIndex,
        uint256 uintValue,
        bool boolValue
    ) public onlyOwner {
        if (ParameterIndex == 1) {
            SPOT_DATA_BATCH_SIZE = uintValue;
        }
        if (ParameterIndex == 2) {
            SPOT_MIN_STAKE = uintValue;
        }
        if (ParameterIndex == 3) {
            SPOT_MIN_CONSENSUS_WORKER_COUNT = uintValue;
        }
        if (ParameterIndex == 4) {
            SPOT_MAX_CONSENSUS_WORKER_COUNT = uintValue;
        }
        if (ParameterIndex == 5) {
            SPOT_COMMIT_ROUND_DURATION = uintValue;
        }
        if (ParameterIndex == 6) {
            SPOT_REVEAL_ROUND_DURATION = uintValue;
        }
        if (ParameterIndex == 7) {
            SPOT_MIN_REWARD_SpotData = uintValue;
        }
        if (ParameterIndex == 8) {
            SPOT_MIN_REP_SpotData = uintValue;
        }
        if (ParameterIndex == 9) {
            SPOT_MIN_REWARD_DataValidation = uintValue;
        }
        if (ParameterIndex == 10) {
            SPOT_MIN_REP_DataValidation = uintValue;
        }
        // Spotting DataInput Management system
        if (ParameterIndex == 11) {
            SPOT_INTER_ALLOCATION_DURATION = uintValue;
        }
        if (ParameterIndex == 12) {
            SPOT_TOGGLE_ENABLED = boolValue;
        }
        if (ParameterIndex == 13) {
            SPOT_TIMEFRAME_DURATION = uintValue;
        }
        if (ParameterIndex == 14) {
            SPOT_GLOBAL_MAX_SPOT_PER_PERIOD = uintValue;
        }
        if (ParameterIndex == 15) {
            SPOT_MAX_SPOT_PER_USER_PER_PERIOD = uintValue;
        }
        if (ParameterIndex == 16) {
            SPOT_NB_TIMEFRAMES = uintValue;
        }
        if (ParameterIndex == 17) {
            MAX_SUCCEEDING_NOVOTES = uintValue;
        }
        if (ParameterIndex == 18) {
            NOVOTE_REGISTRATION_WAIT_DURATION = uintValue;
        }
    }

    function updateComplianceParameters(uint256 ParameterIndex, uint256 uintValue) public onlyOwner {
        if (ParameterIndex == 1) {
            COMPLIANCE_DATA_BATCH_SIZE = uintValue;
        }
        if (ParameterIndex == 2) {
            COMPLIANCE_MIN_STAKE = uintValue;
        }
        if (ParameterIndex == 3) {
            COMPLIANCE_MIN_CONSENSUS_WORKER_COUNT = uintValue;
        }
        if (ParameterIndex == 4) {
            COMPLIANCE_MAX_CONSENSUS_WORKER_COUNT = uintValue;
        }
        if (ParameterIndex == 5) {
            COMPLIANCE_COMMIT_ROUND_DURATION = uintValue;
        }
        if (ParameterIndex == 6) {
            COMPLIANCE_REVEAL_ROUND_DURATION = uintValue;
        }
        if (ParameterIndex == 7) {
            COMPLIANCE_MIN_REP_DataValidation = uintValue;
        }
        if (ParameterIndex == 8) {
            COMPLIANCE_MIN_REWARD_DataValidation = uintValue;
        }
    }

    function updateIndexingParameters(uint256 ParameterIndex, uint256 uintValue) public onlyOwner {
        if (ParameterIndex == 1) {
            INDEXING_DATA_BATCH_SIZE = uintValue;
        }
        if (ParameterIndex == 2) {
            INDEXING_MIN_STAKE = uintValue;
        }
        if (ParameterIndex == 3) {
            INDEXING_MIN_CONSENSUS_WORKER_COUNT = uintValue;
        }
        if (ParameterIndex == 4) {
            INDEXING_MAX_CONSENSUS_WORKER_COUNT = uintValue;
        }
        if (ParameterIndex == 5) {
            INDEXING_COMMIT_ROUND_DURATION = uintValue;
        }
        if (ParameterIndex == 6) {
            INDEXING_REVEAL_ROUND_DURATION = uintValue;
        }
        if (ParameterIndex == 7) {
            INDEXING_MIN_REP_DataValidation = uintValue;
        }
        if (ParameterIndex == 8) {
            INDEXING_MIN_REWARD_DataValidation = uintValue;
        }
    }

    function updateArchivingParameters(uint256 ParameterIndex, uint256 uintValue) public onlyOwner {
        if (ParameterIndex == 1) {
            ARCHIVING_DATA_BATCH_SIZE = uintValue;
        }
        if (ParameterIndex == 2) {
            ARCHIVING_MIN_STAKE = uintValue;
        }
        if (ParameterIndex == 3) {
            ARCHIVING_MIN_CONSENSUS_WORKER_COUNT = uintValue;
        }
        if (ParameterIndex == 4) {
            ARCHIVING_MAX_CONSENSUS_WORKER_COUNT = uintValue;
        }
        if (ParameterIndex == 5) {
            ARCHIVING_COMMIT_ROUND_DURATION = uintValue;
        }
        if (ParameterIndex == 6) {
            ARCHIVING_REVEAL_ROUND_DURATION = uintValue;
        }
        if (ParameterIndex == 7) {
            ARCHIVING_MIN_REP_DataValidation = uintValue;
        }
        if (ParameterIndex == 8) {
            ARCHIVING_MIN_REWARD_DataValidation = uintValue;
        }
    }

    // -------------- GETTERS : GENERAL --------------------
    function getMaxTotalWorkers() public view returns (uint256) {
        return MAX_TOTAL_WORKERS;
    }

    function getVoteQuorum() public view returns (uint256) {
        return VOTE_QUORUM;
    }

    function get_MAX_UPDATE_ITERATIONS() public view returns (uint256) {
        return MAX_UPDATE_ITERATIONS;
    }

    function get_MAX_CONTRACT_STORED_BATCHES() public view returns (uint256) {
        return MAX_CONTRACT_STORED_BATCHES;
    }

    // -------------- GETTERS : ADDRESSES --------------------
    function getStakeManager() public view returns (address) {
        return StakeManager;
    }

    function getRepManager() public view returns (address) {
        return RepManager;
    }

    function getReputationSystem() public view returns (address) {
        return Reputation;
    }

    function getAddressManager() public view returns (address) {
        return AddressManager;
    }

    function getRewardManager() public view returns (address) {
        return RewardManager;
    }

    function getSpottingSystem() public view returns (address) {
        return SpottingSystem;
    }

    function getComplianceSystem() public view returns (address) {
        return ComplianceSystem;
    }

    function getIndexingSystem() public view returns (address) {
        return IndexingSystem;
    }

    function getArchivingSystem() public view returns (address) {
        return ArchivingSystem;
    }

    function getsFuelSystem() public view returns (address) {
        return sFuel;
    }

    function getExordeToken() public view returns (address) {
        return token;
    }

    // -------------- GETTERS : SPOTTING --------------------
    function get_SPOT_DATA_BATCH_SIZE() public view returns (uint256) {
        return SPOT_DATA_BATCH_SIZE;
    }

    function get_SPOT_MIN_STAKE() public view returns (uint256) {
        return SPOT_MIN_STAKE;
    }

    function get_SPOT_MIN_CONSENSUS_WORKER_COUNT() public view returns (uint256) {
        return SPOT_MIN_CONSENSUS_WORKER_COUNT;
    }

    function get_SPOT_MAX_CONSENSUS_WORKER_COUNT() public view returns (uint256) {
        return SPOT_MAX_CONSENSUS_WORKER_COUNT;
    }

    function get_SPOT_COMMIT_ROUND_DURATION() public view returns (uint256) {
        return SPOT_COMMIT_ROUND_DURATION;
    }

    function get_SPOT_REVEAL_ROUND_DURATION() public view returns (uint256) {
        return SPOT_REVEAL_ROUND_DURATION;
    }

    function get_SPOT_MIN_REP_SpotData() public view returns (uint256) {
        return SPOT_MIN_REP_SpotData;
    }

    function get_SPOT_MIN_REWARD_SpotData() public view returns (uint256) {
        return SPOT_MIN_REWARD_SpotData;
    }

    function get_SPOT_MIN_REP_DataValidation() public view returns (uint256) {
        return SPOT_MIN_REP_DataValidation;
    }

    function get_SPOT_MIN_REWARD_DataValidation() public view returns (uint256) {
        return SPOT_MIN_REWARD_DataValidation;
    }

    function get_SPOT_INTER_ALLOCATION_DURATION() public view returns (uint256) {
        return SPOT_INTER_ALLOCATION_DURATION;
    }

    function get_SPOT_TOGGLE_ENABLED() public view returns (bool) {
        return SPOT_TOGGLE_ENABLED;
    }

    function get_SPOT_TIMEFRAME_DURATION() public view returns (uint256) {
        return SPOT_TIMEFRAME_DURATION;
    }

    function get_SPOT_GLOBAL_MAX_SPOT_PER_PERIOD() public view returns (uint256) {
        return SPOT_GLOBAL_MAX_SPOT_PER_PERIOD;
    }

    function get_SPOT_MAX_SPOT_PER_USER_PER_PERIOD() public view returns (uint256) {
        return SPOT_MAX_SPOT_PER_USER_PER_PERIOD;
    }

    function get_SPOT_NB_TIMEFRAMES() public view returns (uint256) {
        return SPOT_NB_TIMEFRAMES;
    }

    function get_MAX_SUCCEEDING_NOVOTES() public view returns (uint256) {
        return MAX_SUCCEEDING_NOVOTES;
    }

    function get_NOVOTE_REGISTRATION_WAIT_DURATION() public view returns (uint256) {
        return NOVOTE_REGISTRATION_WAIT_DURATION;
    }

    // -------------- GETTERS : Compliance --------------------
    function get_COMPLIANCE_DATA_BATCH_SIZE() public view returns (uint256) {
        return COMPLIANCE_DATA_BATCH_SIZE;
    }

    function get_COMPLIANCE_MIN_STAKE() public view returns (uint256) {
        return COMPLIANCE_MIN_STAKE;
    }

    function get_COMPLIANCE_MIN_CONSENSUS_WORKER_COUNT() public view returns (uint256) {
        return COMPLIANCE_MIN_CONSENSUS_WORKER_COUNT;
    }

    function get_COMPLIANCE_MAX_CONSENSUS_WORKER_COUNT() public view returns (uint256) {
        return COMPLIANCE_MAX_CONSENSUS_WORKER_COUNT;
    }

    function get_COMPLIANCE_COMMIT_ROUND_DURATION() public view returns (uint256) {
        return COMPLIANCE_COMMIT_ROUND_DURATION;
    }

    function get_COMPLIANCE_REVEAL_ROUND_DURATION() public view returns (uint256) {
        return COMPLIANCE_REVEAL_ROUND_DURATION;
    }

    function get_COMPLIANCE_MIN_REWARD_DataValidation() public view returns (uint256) {
        return COMPLIANCE_MIN_REWARD_DataValidation;
    }

    function get_COMPLIANCE_MIN_REP_DataValidation() public view returns (uint256) {
        return COMPLIANCE_MIN_REP_DataValidation;
    }

    // -------------- GETTERS : Indexing --------------------
    function get_INDEXING_DATA_BATCH_SIZE() public view returns (uint256) {
        return INDEXING_DATA_BATCH_SIZE;
    }

    function get_INDEXING_MIN_STAKE() public view returns (uint256) {
        return INDEXING_MIN_STAKE;
    }

    function get_INDEXING_MIN_CONSENSUS_WORKER_COUNT() public view returns (uint256) {
        return INDEXING_MIN_CONSENSUS_WORKER_COUNT;
    }

    function get_INDEXING_MAX_CONSENSUS_WORKER_COUNT() public view returns (uint256) {
        return INDEXING_MAX_CONSENSUS_WORKER_COUNT;
    }

    function get_INDEXING_COMMIT_ROUND_DURATION() public view returns (uint256) {
        return INDEXING_COMMIT_ROUND_DURATION;
    }

    function get_INDEXING_REVEAL_ROUND_DURATION() public view returns (uint256) {
        return INDEXING_REVEAL_ROUND_DURATION;
    }

    function get_INDEXING_MIN_REWARD_DataValidation() public view returns (uint256) {
        return INDEXING_MIN_REWARD_DataValidation;
    }

    function get_INDEXING_MIN_REP_DataValidation() public view returns (uint256) {
        return INDEXING_MIN_REP_DataValidation;
    }

    // -------------- GETTERS : Archiving --------------------
    function get_ARCHIVING_DATA_BATCH_SIZE() public view returns (uint256) {
        return ARCHIVING_DATA_BATCH_SIZE;
    }

    function get_ARCHIVING_MIN_STAKE() public view returns (uint256) {
        return ARCHIVING_MIN_STAKE;
    }

    function get_ARCHIVING_MIN_CONSENSUS_WORKER_COUNT() public view returns (uint256) {
        return ARCHIVING_MIN_CONSENSUS_WORKER_COUNT;
    }

    function get_ARCHIVING_MAX_CONSENSUS_WORKER_COUNT() public view returns (uint256) {
        return ARCHIVING_MAX_CONSENSUS_WORKER_COUNT;
    }

    function get_ARCHIVING_COMMIT_ROUND_DURATION() public view returns (uint256) {
        return ARCHIVING_COMMIT_ROUND_DURATION;
    }

    function get_ARCHIVING_REVEAL_ROUND_DURATION() public view returns (uint256) {
        return ARCHIVING_REVEAL_ROUND_DURATION;
    }

    function get_ARCHIVING_MIN_REWARD_DataValidation() public view returns (uint256) {
        return ARCHIVING_MIN_REWARD_DataValidation;
    }

    function get_ARCHIVING_MIN_REP_DataValidation() public view returns (uint256) {
        return ARCHIVING_MIN_REP_DataValidation;
    }
}
