// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ISpottingSystem {
    enum DataStatus {
        TBD,
        APPROVED,
        REJECTED,
        FLAGGED
    }

    // ------ Data batch Structure
    struct BatchMetadata {
        uint256 start_idx;
        uint256 counter;
        uint256 uncommited_workers;
        uint256 unrevealed_workers;
        bool complete;
        bool checked;
        bool allocated_to_work;
        uint256 commitEndDate; // expiration date of commit period for poll
        uint256 revealEndDate; // expiration date of reveal period for poll
        uint256 votesFor; // tally of spot-check-votes supporting proposal
        uint256 votesAgainst; // tally of spot-check-votes countering proposal
        string batchIPFSfile; // to be updated during SpotChecking
        uint256 item_count;
        DataStatus status; // state of the vote
    }

    struct SpottedData {
        string ipfs_hash; // expiration date of commit period for SpottedData
        address author; // author of the proposal
        uint256 timestamp; // expiration date of commit period for SpottedData
        uint256 item_count;
        string URL_domain; // URL domain
        string extra; // extra_data
        DataStatus status; // state of the vote
    }


    function AllWorkersList() external view returns (address[] memory);
    function AllWorkersList(uint256) external view returns (address[] memory);
    function WorkersPerBatch (uint256) external view returns(address[] memory);
    function getDataByID(uint256 _DataId) external view returns (SpottedData memory data);
    function getBatchIPFSFileByID(uint256 _DataBatchId) external view returns (string memory batch);
    function getBatchByID(uint256 _DataBatchId) external view returns (BatchMetadata memory batch);
    function DataExists(uint256 _DataBatchId) external view returns (bool exists);
}


contract SpotReader is Ownable {

    ISpottingSystem DataSpotting;

    constructor(address DataSpotting_){
        DataSpotting = ISpottingSystem(DataSpotting_);
    }

    function getBatchsFilesByID(uint256 _DataBatchId_a, uint256 _DataBatchId_b)
        public
        view
        returns (string[] memory)
    {
        require(_DataBatchId_a > 0 && _DataBatchId_a < _DataBatchId_b, "Input boundaries are invalid");
        uint256 _array_size = _DataBatchId_b - _DataBatchId_a;
        string[] memory ipfs_hash_list = new string[](_array_size);
        for (uint256 i = 0; i < _array_size; i++) {
            ipfs_hash_list[i] = DataSpotting.getBatchIPFSFileByID(_DataBatchId_a + i);
        }
        return ipfs_hash_list;
    }


    function getSpotAuthorsByID(uint256 _DataId_a, uint256 _DataId_b)
        public
        view
        returns (address[] memory)
    {
        require(_DataId_a > 0 && _DataId_a < _DataId_b, "Input boundaries are invalid");
        uint256 _array_size = _DataId_b - _DataId_a;
        address[] memory addresses_list = new address[](_array_size);
        for (uint256 i = 0; i < _array_size; i++) {
            addresses_list[i] = DataSpotting.getDataByID(_DataId_a + i).author;
        }
        return addresses_list;
    }


    function getWorkersPerBatch(uint256 _DataBatchId_a)
        public
        view
        returns (address[] memory)
    {
        address[] memory allocated_worker = DataSpotting.WorkersPerBatch(_DataBatchId_a);
        return allocated_worker;
    }

    function getNumberAddr(address DataSpotting_) external view returns (uint256) {
        return ISpottingSystem(DataSpotting_).AllWorkersList().length;
    }

    function getAddr1(address DataSpotting_, uint256 i) external view returns (address) {
        return ISpottingSystem(DataSpotting_).AllWorkersList()[i];
    }

    function getAddr2(address DataSpotting_, uint256 i) external view returns (address[] memory) {
        return ISpottingSystem(DataSpotting_).AllWorkersList(i);
    }


    function getAllWorkersCount()
        public 
        view
        returns(uint256 array_length)
    {
        return DataSpotting.AllWorkersList().length;
    }

    function getAllWorkersAtIndex(uint256 i)
        public 
        view
        returns(address[] memory worker_i)
    {
        return DataSpotting.AllWorkersList(i);
    }
}