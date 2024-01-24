// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;


interface IDataQualityBase {
    

    // ------ Data batch Structure : 4 slots
    struct BatchMetadata {
        uint128 start_idx;
        uint32 counter;
        uint32 item_count;
        bool complete;
        bool quality_checked;
        bool relevance_checked;
        bool allocated_to_work;
    }

    struct ProcessMetadata {
        uint128 start_idx;
        uint32 counter;
        uint32 item_count;
        uint16 uncommited_quality_workers;
        uint16 unrevealed_quality_workers;
        uint16 uncommited_relevance_workers;
        uint16 unrevealed_relevance_workers;
        bool complete;
        bool quality_checked;
        bool relevance_checked;
        bool allocated_to_work;
        uint64 quality_commitEndDate; // expiration date of commit period for the quality round
        uint64 quality_revealEndDate; // expiration date of reveal period for the quality round
        uint64 relevance_commitEndDate; // expiration date of commit period for the relevance round
        uint64 relevance_revealEndDate; // expiration date of reveal period for the relevance round
    }

    // ------ Spot-flow related structure : 1 slots
    struct TimeframeCounter {
        uint128 timestamp;
        uint128 counter;
    }

    // ------ Commit Reveal struct : 1 slot
    struct WorkerStatus {
        bool isActiveWorker;
        bool isAvailableWorker;
        bool isBusyWorker;
        bool isToUnregisterWorker;
        uint32 activeWorkersIndex;
        uint32 availableWorkersIndex;
        uint32 busyWorkersIndex;
        uint32 toUnregisterWorkersIndex;
    }
}
