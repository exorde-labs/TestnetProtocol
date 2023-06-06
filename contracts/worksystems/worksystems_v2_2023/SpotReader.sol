// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDataSpotting {
    
    enum DataStatus {
        TBD,
        APPROVED,
        REJECTED,
        FLAGGED
    }

    // ------ Spot-flow related structure : 1 slots
    struct TimeframeCounter {
        uint128 timestamp;
        uint128 counter;
    }

    // ------ Worker State Structure : 2 slots
    struct WorkerState {
        uint128 allocated_work_batch;
        uint64 last_interaction_date;
        uint16 succeeding_novote_count;
        bool registered;
        bool unregistration_request;
        bool isWorkerSeen;
        uint64 registration_date;
        uint64 allocated_batch_counter;
        uint64 majority_counter;
        uint64 minority_counter;
    }


    
    // ------ Data batch Structure : 4 slots
    struct BatchMetadata {
        uint128 start_idx;
        uint32 counter;
        uint32 item_count;
        uint16 uncommited_workers;
        uint16 unrevealed_workers;
        bool complete;
        bool checked;
        bool allocated_to_work;
        DataStatus status; // state of the vote
        uint16 votesFor; // tally of spot-check-votes supporting proposal
        uint16 votesAgainst; // tally of spot-check-votes countering proposal
        uint64 commitEndDate; // expiration date of commit period for poll
        uint64 revealEndDate; // expiration date of reveal period for poll
        string batchIPFSfile; // to be updated during SpotChecking
    }

    // ------ Atomic Data Structure : 5 slots
    struct SpottedData {
        uint64 timestamp; // expiration date of commit period for SpottedData
        uint64 item_count;
        // uint16 lang;    // language of the spotted data (all sub items must be of the same language)
        DataStatus status; // state of the vote
        string extra; // extra_data
        address author; // author of the proposal
        string ipfs_hash; // expiration date of commit period for SpottedData
        string URL_domain; // URL domain
    }


    // ------ User VoteSubmission struct  : 4 slots
    struct VoteSubmission {
        bool commited;
        bool revealed;
        uint8 vote;
        uint32 batchCount;
        string newFile;
        string batchFrom;
    }

    // ------ Commit Reveal struct : 1 slot
    struct WorkerStatus {
        bool isAvailableWorker;
        bool isBusyWorker;
        bool isToUnregisterWorker;
        uint32 availableWorkersIndex;
        uint32 busyWorkersIndex;
        uint32 toUnregisterWorkersIndex;
    }
    /**
     * @notice get DataBatch By ID
     * @return batch as BatchMetadata struct
     */
    function getBatchByID(uint128 _DataBatchId) external view returns(BatchMetadata memory batch);

    /**
     * @notice get Output Batch IPFS File By ID
     * @return batch IPFS File
     */
    function getBatchIPFSFileByID(uint128 _DataBatchId) external view returns(string memory batch);

    
    /**
     * @notice get Data By ID
     * @return data as SpottedData struct
     */
    function getDataByID(uint128 _DataId) external  view returns(SpottedData memory data);
}


contract SpotReader is Ownable {

    enum DataStatus {
        TBD,
        APPROVED,
        REJECTED,
        FLAGGED
    }

    // ------ Spot-flow related structure : 1 slots
    struct TimeframeCounter {
        uint128 timestamp;
        uint128 counter;
    }

    // ------ Worker State Structure : 2 slots
    struct WorkerState {
        uint128 allocated_work_batch;
        uint64 last_interaction_date;
        uint16 succeeding_novote_count;
        bool registered;
        bool unregistration_request;
        bool isWorkerSeen;
        uint64 registration_date;
        uint64 allocated_batch_counter;
        uint64 majority_counter;
        uint64 minority_counter;
    }


    // ------ Data batch Structure : 4 slots
    struct BatchMetadata {
        uint128 start_idx;
        uint32 counter;
        uint32 item_count;
        uint16 uncommited_workers;
        uint16 unrevealed_workers;
        bool complete;
        bool checked;
        bool allocated_to_work;
        DataStatus status; // state of the vote
        uint16 votesFor; // tally of spot-check-votes supporting proposal
        uint16 votesAgainst; // tally of spot-check-votes countering proposal
        uint64 commitEndDate; // expiration date of commit period for poll
        uint64 revealEndDate; // expiration date of reveal period for poll
        string batchIPFSfile; // to be updated during SpotChecking
    }

    // ------ Atomic Data Structure : 5 slots
    struct SpottedData {
        uint64 timestamp; // expiration date of commit period for SpottedData
        uint64 item_count;
        // uint16 lang;    // language of the spotted data (all sub items must be of the same language)
        DataStatus status; // state of the vote
        string extra; // extra_data
        address author; // author of the proposal
        string ipfs_hash; // expiration date of commit period for SpottedData
        string URL_domain; // URL domain
    }


    // ------ User VoteSubmission struct  : 4 slots
    struct VoteSubmission {
        bool commited;
        bool revealed;
        uint8 vote;
        uint32 batchCount;
        string newFile;
        string batchFrom;
    }

    // ------ Commit Reveal struct : 1 slot
    struct WorkerStatus {
        bool isAvailableWorker;
        bool isBusyWorker;
        bool isToUnregisterWorker;
        uint32 availableWorkersIndex;
        uint32 busyWorkersIndex;
        uint32 toUnregisterWorkersIndex;
    }

    IDataSpotting public DataSpotting;

    constructor(address DataSpotting_){
        DataSpotting = IDataSpotting(DataSpotting_);
    }

    function getSpotAuthors(uint128 batch_id)
        public
        view
        returns (address[] memory)
    {
        IDataSpotting.BatchMetadata memory batch_ = DataSpotting.getBatchByID(batch_id);
        uint128 spot_start_idx = batch_.start_idx;
        uint32 counter = batch_.counter;
        address[] memory authors = new address[](counter);
        for (uint128 i = 0; i < authors.length; i++) {
            uint128 spot_idx = spot_start_idx + i;
            authors[i] = DataSpotting.getDataByID(spot_idx).author;
        }
        return authors;
    }

}