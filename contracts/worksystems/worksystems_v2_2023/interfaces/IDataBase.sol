// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;


interface IDataBase {
    
    // ------ Data batch status
    enum DataStatus {
        TBD,
        APPROVED,
        REJECTED,
        FLAGGED
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

    // ------ Spot-flow related structure : 1 slots
    struct TimeframeCounter {
        uint128 timestamp;
        uint128 counter;
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
}
