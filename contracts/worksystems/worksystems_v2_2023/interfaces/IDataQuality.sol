// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;


import "./IDataQualityBase.sol";

interface IDataQuality is IDataQualityBase {

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

    // ------ Atomic Data Structure : 5 slots
    struct SpottedData {
        uint64 timestamp; // expiration date of commit period for SpottedData
        uint64 item_count;
        // uint16 lang;    // language of the spotted data (all sub items must be of the same language)
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

    // ------ Atomic Data Structure : 5 slots
    struct QualityData {
        uint64 timestamp; // expiration date of commit period for QualityData
        uint64 unverified_item_count;
        // uint16 lang;    // language of the Quality data (all sub items must be of the same language)
        address author; // author of the proposal
        string ipfs_hash; // expiration date of commit period for QualityData
    }

    /**
     * @notice get DataBatch By ID
     * @return batch as BatchMetadata struct
     */
    function getBatchByID(uint128 _DataBatchId) external view returns(BatchMetadata memory batch);

    /**
     * @notice get Data By ID
     * @return data as QualityData struct
     */
    function getDataByID(uint128 _DataId) external view returns(QualityData memory data);
    
}
