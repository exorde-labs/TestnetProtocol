// SPDX-License-Identifier: GPL-3.0
// File: attrstore/AttributeStore.sol

pragma solidity 0.8.0;

library AttributeStore4 {
    struct ArchiveData {
        mapping(bytes32 => uint256) store;
    }

    function getAttribute(
        ArchiveData storage self,
        bytes32 _UUID,
        string memory _attrName
    ) public view returns (uint256) {
        bytes32 key = keccak256(abi.encodePacked(_UUID, _attrName));
        return self.store[key];
    }

    function setAttribute(
        ArchiveData storage self,
        bytes32 _UUID,
        string memory _attrName,
        uint256 _attrVal
    ) public {
        bytes32 key = keccak256(abi.encodePacked(_UUID, _attrName));
        self.store[key] = _attrVal;
    }
}

// File: dll/DLL.sol

library DLL4 {
    uint256 constant NULL_NODE_ID = 0;

    struct Node {
        uint256 next;
        uint256 prev;
    }

    struct ArchiveData {
        mapping(uint256 => Node) dll;
    }

    function isEmpty(ArchiveData storage self) public view returns (bool) {
        return getStart(self) == NULL_NODE_ID;
    }

    function contains(ArchiveData storage self, uint256 _curr) public view returns (bool) {
        if (isEmpty(self) || _curr == NULL_NODE_ID) {
            return false;
        }

        bool isSingleNode = (getStart(self) == _curr) && (getEnd(self) == _curr);
        bool isNullNode = (getNext(self, _curr) == NULL_NODE_ID) && (getPrev(self, _curr) == NULL_NODE_ID);
        return isSingleNode || !isNullNode;
    }

    function getNext(ArchiveData storage self, uint256 _curr) public view returns (uint256) {
        return self.dll[_curr].next;
    }

    function getPrev(ArchiveData storage self, uint256 _curr) public view returns (uint256) {
        return self.dll[_curr].prev;
    }

    function getStart(ArchiveData storage self) public view returns (uint256) {
        return getNext(self, NULL_NODE_ID);
    }

    function getEnd(ArchiveData storage self) public view returns (uint256) {
        return getPrev(self, NULL_NODE_ID);
    }

    /**
  @dev Inserts a new node between _prev and _next. When inserting a node already existing in 
  the list it will be automatically removed from the old position.
  @param _prev the node which _new will be inserted after
  @param _curr the id of the new node being inserted
  @param _next the node which _new will be inserted before
  */
    function insert(
        ArchiveData storage self,
        uint256 _prev,
        uint256 _curr,
        uint256 _next
    ) public {
        require(_curr != NULL_NODE_ID, "error: could not insert, 1");

        remove(self, _curr);

        require(_prev == NULL_NODE_ID || contains(self, _prev), "error: could not insert, 2");
        require(_next == NULL_NODE_ID || contains(self, _next), "error: could not insert, 3");

        require(getNext(self, _prev) == _next, "error: could not insert, 4");
        require(getPrev(self, _next) == _prev, "error: could not insert, 5");

        self.dll[_curr].prev = _prev;
        self.dll[_curr].next = _next;

        self.dll[_prev].next = _curr;
        self.dll[_next].prev = _curr;
    }

    function remove(ArchiveData storage self, uint256 _curr) public {
        if (!contains(self, _curr)) {
            return;
        }

        uint256 next = getNext(self, _curr);
        uint256 prev = getPrev(self, _curr);

        self.dll[next].prev = prev;
        self.dll[prev].next = next;

        delete self.dll[_curr];
    }
}

interface IParametersManager {
    // -------------- GETTERS : GENERAL --------------------
    function getMaxTotalWorkers() external view returns (uint256);

    function getVoteQuorum() external view returns (uint256);

    function get_MAX_UPDATE_ITERATIONS() external view returns (uint256);

    function get_MAX_CONTRACT_STORED_BATCHES() external view returns (uint256);

    function get_MAX_SUCCEEDING_NOVOTES() external view returns (uint256);

    function get_NOVOTE_REGISTRATION_WAIT_DURATION() external view returns (uint256);

    // -------------- GETTERS : ADDRESSES --------------------
    function getStakeManager() external view returns (address);

    function getRepManager() external view returns (address);

    function getAddressManager() external view returns (address);

    function getRewardManager() external view returns (address);

    function getArchivingSystem() external view returns (address);

    function getSpottingSystem() external view returns (address);

    function getComplianceSystem() external view returns (address);

    function getIndexingSystem() external view returns (address);

    function getsFuelSystem() external view returns (address);

    function getExordeToken() external view returns (address);

    // -------------- GETTERS : ARCHIVING --------------------
    function get_ARCHIVING_DATA_BATCH_SIZE() external view returns (uint256);

    function get_ARCHIVING_MIN_STAKE() external view returns (uint256);

    function get_ARCHIVING_MIN_CONSENSUS_WORKER_COUNT() external view returns (uint256);

    function get_ARCHIVING_MAX_CONSENSUS_WORKER_COUNT() external view returns (uint256);

    function get_ARCHIVING_COMMIT_ROUND_DURATION() external view returns (uint256);

    function get_ARCHIVING_REVEAL_ROUND_DURATION() external view returns (uint256);

    function get_ARCHIVING_MIN_REWARD_DataValidation() external view returns (uint256);

    function get_ARCHIVING_MIN_REP_DataValidation() external view returns (uint256);
}

interface IStakeManager {
    function ProxyStakeAllocate(uint256 _StakeAllocation, address _stakeholder) external returns (bool);

    function ProxyStakeDeallocate(uint256 _StakeToDeallocate, address _stakeholder) external returns (bool);
}

interface IRepManager {
    function mintReputationForWork(
        uint256 _amount,
        address _beneficiary,
        bytes32
    ) external returns (bool);

    function burnReputationForWork(
        uint256 _amount,
        address _beneficiary,
        bytes32
    ) external returns (bool);
}

interface IRewardManager {
    function ProxyAddReward(uint256 _RewardsAllocation, address _user) external returns (bool);
}

interface IAddressManager {
    function isMasterOf(address _master, address _address) external returns (bool);

    function isSubWorkerOf(address _master, address _address) external returns (bool);

    function AreMasterSubLinked(address _master, address _address) external returns (bool);

    function getMasterSubs(address _master) external view returns (address);

    function getMaster(address _worker) external view returns (address);

    function FetchHighestMaster(address _worker) external view returns (address);
}

interface IPreviousSystem {
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

    function getBatchByID(uint256 _DataBatchId) external returns (BatchMetadata memory batch);

    function DataExists(uint256 _DataBatchId) external returns (bool exists);
}

interface IArchivingSystem {
    function Ping(uint256 CheckedBatchId) external returns (bool);
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RandomAllocator.sol";

/**
@title WorkSystem Archive v0.2
@author Mathias Dail
*/
contract DataArchiving is Ownable, RandomAllocator {
    // ================================================================================================
    // Success ratios of the WorkSystem pipeline are defined depending on task subjectivity & complexity.
    //     Desired overall success ratio is defined as the following: Data Output flux >= 0.80 Data Input Flux. This translates
    //     in the following:
    //         - Archiving: 0. 90%
    //         - Archive-Checking: 0.99%
    //         - Archiving: 0.95%
    //         - Archive-Checking: 0.99%
    //         - Archiving: 0.99%
    //         - Archive-Checking: 0.99%
    // ================================================================================================
    //     This leaves room for 1% spread out on "frozen stakes" (stakes that are attributed to work that is never processed
    //     by the rest of the pipeline) & flagged content. This is allocated as follows:
    //         - Frozen Archive Stakes: 0.3%
    //         - Frozen Archive-Checking Stakes: 0.2%
    //         - Frozen Archiving Stakes: 0.2%
    //         - Frozen Archive-Checking Stakes: 0.1%
    //         - Frozen Archiving Stakes: 0.1%
    //         - Flagged Content: 0.1%
    // ================================================================================================

    // ============ EVENTS ============
    event _ArchiveSubmitted(uint256 indexed DataID, string file_hash, address sender);
    event _ArchiveCheckCommitted(uint256 indexed DataID, uint256 numTokens, address indexed voter);
    event _ArchiveCheckRevealed(
        uint256 indexed DataID,
        uint256 numTokens,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 indexed choice,
        address indexed voter
    );
    event _ArchiveAccepted(string hash, address indexed creator);
    event _WorkAllocated(uint256 indexed batchID, address worker);
    event _WorkerRegistered(address indexed worker, uint256 timestamp);
    event _WorkerUnregistered(address indexed worker, uint256 timestamp);
    event _StakeAllocated(uint256 numTokens, address indexed voter);
    event _VotingRightsWithdrawn(uint256 numTokens, address indexed voter);
    event _TokensRescued(uint256 indexed DataID, address indexed voter);
    event _DataBatchDeleted(uint256 indexed batchID);

    // ============ LIBRARIES ============
    using AttributeStore4 for AttributeStore4.ArchiveData;
    using DLL4 for DLL4.ArchiveData;
    using SafeMath for uint256;

    // ============ DATA STRUCTURES ============
    enum DataStatus {
        TBD,
        APPROVED,
        REJECTED,
        FLAGGED
    }

    // ------ Worker State Structure
    struct WorkerState {
        address worker_address; // worker address
        uint256 allocated_work_batch;
        bool has_completed_work;
        uint256 succeeding_novote_count;
        uint256 last_interaction_date;
        bool registered;
        bool unregistration_request;
        uint256 registration_date;
        uint256 majority_counter;
        uint256 minority_counter;
    }

    // ------ Data batch Structure
    struct BatchMetadata {
        uint256 start_idx;
        uint256 counter;
        uint256 uncommited_workers;
        uint256 unrevealed_workers;
        uint256 item_count;
        bool complete;
        bool checked;
        bool allocated_to_work;
        uint256 commitEndDate; // expiration date of commit period for poll
        uint256 revealEndDate; // expiration date of reveal period for poll
        uint256 votesFor; // tally of archive-check-votes supporting proposal
        uint256 votesAgainst; // tally of archive-check-votes countering proposal
        string batchIPFSfile; // to be updated during ArchiveChecking
        DataStatus status; // state of the vote
    }

    // ------ Atomic Data Structure
    struct ArchiveData {
        string ipfs_hash; // expiration date of commit period for ArchiveData
        address author; // author of the proposal
        uint256 timestamp; // expiration date of commit period for ArchiveData
        DataStatus status; // state of the vote
    }

    // ====================================
    //        GLOBAL STATE VARIABLES
    // ====================================

    // ------ User (workers) Submissions & Commitees Related Structures
    mapping(address => mapping(uint256 => bool)) public UserChecksCommits; // indicates whether an address committed a archive-check-vote for this poll
    mapping(address => mapping(uint256 => bool)) public UserChecksReveals; // indicates whether an address revealed a archive-check-vote for this poll
    mapping(uint256 => mapping(address => uint256)) public UserVotes; // maps DataID -> user addresses ->  vote option
    mapping(uint256 => mapping(address => string)) public UserNewFiles; // maps DataID -> user addresses -> ipfs string -> counter
    mapping(uint256 => mapping(address => uint256)) public UserBatchCounts; // maps DataID -> user addresses -> ipfs string -> counter
    mapping(uint256 => mapping(address => string)) public UserBatchFrom; // maps DataID -> user addresses -> ipfs string -> counter
    mapping(uint256 => mapping(address => string)) public UserSubmittedStatus; // maps DataID -> user addresses -> ipfs string -> counter

    // ------ Backend Data Stores
    mapping(address => DLL4.ArchiveData) dllMap;
    AttributeStore4.ArchiveData store;
    mapping(uint256 => ArchiveData) public ArchivesMapping; // maps DataID to ArchiveData struct
    mapping(uint256 => BatchMetadata) public DataBatch; // refers to ArchiveData indices

    // ------ Worker & Stake related structure
    mapping(address => WorkerState) public WorkersState;
    mapping(address => uint256) public SystemStakedTokenBalance; // maps user's address to voteToken balance

    // ------ Worker management structures
    mapping(address => address[]) public MasterWorkers;
    mapping(uint256 => address[]) public WorkersPerBatch;
    mapping(uint256 => bool) public CollectedSpotBatchs; // Related to previous system
    address[] public availableWorkers;
    address[] public busyWorkers;
    address[] public toUnregisterWorkers;
    uint256 LastRandomSeed = 0;

    // ------ Fuel Auto Top Up system
    address public sFuel; // owner of sFuelDistributor needs to whitelist this contract

    // ------ Processes counters
    uint256 public DataNonce = 0;
    // -- Batches Counters
    uint256 public BatchDeletionCursor = 1;
    uint256 public LastBatchCounter = 1;
    uint256 public BatchCheckingCursor = 1;
    uint256 public AllocatedBatchCursor = 1;

    // ------ Statistics related counters
    uint256 public AllTxsCounter = 0;
    uint256 public AcceptedBatchsCounter = 0;
    uint256 public RejectedBatchsCounter = 0;
    uint256 public NotCommitedCounter = 0;
    uint256 public NotRevealedCounter = 0;

    // ------ Addresses & Interfaces
    IERC20 public token;
    IParametersManager public Parameters;

    // ============================================================================================================
    /**
    @dev Initializer. Can only be called once.
    */
    constructor(address EXDT_token_) {
        require(address(EXDT_token_) != address(0));
        token = IERC20(EXDT_token_);
    }

    function destroyContract() public onlyOwner {
        selfdestruct(payable(owner()));
    }

    function updateParametersManager(address addr) public onlyOwner {
        Parameters = IParametersManager(addr);
    }

    function updateBatchCheckingCursor(uint256 BatchCheckingCursor_) public onlyOwner {
        BatchCheckingCursor = BatchCheckingCursor_;
    }

    function updateAllocatedBatchCursor(uint256 AllocatedBatchCursor_) public onlyOwner {
        AllocatedBatchCursor = AllocatedBatchCursor_;
    }

    // ----------------------------------------------------------------------------------
    //                          DATA DELETION FUNCTIONS
    // ----------------------------------------------------------------------------------

    function deleteCollectedSpotBatch(uint256 _BatchId) public onlyOwner {
        if (CollectedSpotBatchs[_BatchId]) {
            delete CollectedSpotBatchs[_BatchId];
        }
    }

    function deleteData(uint256 _DataId) public onlyOwner {
        delete ArchivesMapping[_DataId];
    }

    function deleteDataBatch(uint256 _BatchId) public onlyOwner {
        delete DataBatch[_BatchId];
    }

    // This function is most likely not complete enough: need to delete from AttributeStore, need to clean some mappings, if possible.
    function deleteOldData() internal {
        uint256 BatchesToDeleteCount = BatchCheckingCursor - BatchDeletionCursor;
        if (BatchesToDeleteCount > Parameters.get_MAX_CONTRACT_STORED_BATCHES()) {
            for (uint256 i = 0; i < Math.min(Parameters.get_MAX_UPDATE_ITERATIONS(), BatchesToDeleteCount); i++) {
                // Iterate at most Max(MAX_UPDATE_ITERATIONS, BatchesToDeleteCount)
                // First Delete Atomic Data composing the Batch, from start to end indices
                uint256 start_batch_idx = DataBatch[BatchDeletionCursor].start_idx;
                uint256 end_batch_idx = DataBatch[BatchDeletionCursor].start_idx +
                    DataBatch[BatchDeletionCursor].counter;
                for (uint256 l = start_batch_idx; l < end_batch_idx; l++) {
                    deleteData(l); // delete SpotsMapping at index l
                }
                // Then delete the Data Batch
                deleteDataBatch(BatchDeletionCursor);
                emit _DataBatchDeleted(BatchDeletionCursor);
            }
        }
    }

    // ----------------------------------------------------------------------------------
    //                          Fuel Auto Top Up system
    // ----------------------------------------------------------------------------------

    function updatesFuelFaucet(address _sFuel) public onlyOwner {
        sFuel = _sFuel;
    }

    // function _retrieveSFuel() internal {
    //     require(sFuel != address(0), "0 Address Not Valid");
    // 	(bool success1, /* bytes memory data1 */) = sFuel.call(abi.encodeWithSignature("retrieveSFuel(address)", payable(msg.sender)));
    //     (bool success2, /* bytes memory data2 */) = sFuel.call(abi.encodeWithSignature("retrieveSFuel(address payable)", payable(msg.sender)));
    //     require(( success1 || success2 ), "receiver rejected _retrieveSFuel call");

    // }

    function _retrieveSFuel() internal {
        address sFuelAddress;
        try Parameters.getsFuelSystem() {} catch (bytes memory err) {
            emit BytesFailure(err);
        }
        sFuelAddress = Parameters.getsFuelSystem();
        require(sFuelAddress != address(0), "sFuel: null Address Not Valid");
        (
            bool success1, /* bytes memory data1 */

        ) = sFuelAddress.call(abi.encodeWithSignature("retrieveSFuel(address)", payable(msg.sender)));
        (
            bool success2, /* bytes memory data2 */

        ) = sFuelAddress.call(abi.encodeWithSignature("retrieveSFuel(address payable)", payable(msg.sender)));
        require((success1 || success2), "receiver rejected _retrieveSFuel call");
    }

    modifier topUpSFuel() {
        _retrieveSFuel();
        _;
    }

    // ----------------------------------------------------------------------------------
    //                          WORKER REGISTRATION & LOBBY MANAGEMENT
    // ----------------------------------------------------------------------------------

    function isInAvailableWorkers(address _worker) internal view returns (bool) {
        bool found = false;
        for (uint256 i = 0; i < availableWorkers.length; i++) {
            if (availableWorkers[i] == _worker) {
                found = true;
                break;
            }
        }
        return found;
    }

    function isInBusyWorkers(address _worker) internal view returns (bool) {
        bool found = false;
        for (uint256 i = 0; i < busyWorkers.length; i++) {
            if (busyWorkers[i] == _worker) {
                found = true;
                break;
            }
        }
        return found;
    }

    function PopFromAvailableWorkers(address _worker) internal {
        uint256 index = 0;
        bool found = false;
        for (uint256 i = 0; i < availableWorkers.length; i++) {
            if (availableWorkers[i] == _worker) {
                found = true;
                index = i;
                break;
            }
        }
        // require(found, "not found when PopFromAvailableWorkers");
        if (found) {
            availableWorkers[index] = availableWorkers[availableWorkers.length - 1];
            availableWorkers.pop();
        }
    }

    function PopFromBusyWorkers(address _worker) internal {
        uint256 index = 0;
        bool found = false;
        for (uint256 i = 0; i < busyWorkers.length; i++) {
            if (busyWorkers[i] == _worker) {
                found = true;
                index = i;
                break;
            }
        }
        // require(found, "not found when PopFromBusyWorkers");
        if (found) {
            busyWorkers[index] = busyWorkers[busyWorkers.length - 1];
            busyWorkers.pop();
        }
    }

    function isWorkerAllocatedToBatch(uint256 _DataBatchId, address _worker) public view returns (bool) {
        bool found = false;
        address[] memory allocated_workers_ = WorkersPerBatch[_DataBatchId];
        for (uint256 i = 0; i < allocated_workers_.length; i++) {
            if (allocated_workers_[i] == _worker) {
                found = true;
                break;
            }
        }
        return found;
    }

    /////////////////////////////////////////////////////////////////////
    /* Register worker (online) */
    function RegisterWorker() public topUpSFuel {
        WorkerState storage worker_state = WorkersState[msg.sender];
        require(
            (availableWorkers.length + busyWorkers.length) < Parameters.getMaxTotalWorkers(),
            "Maximum registered workers already"
        );
        require(worker_state.registered == false, "Worker is already registered");
        require(Parameters.getAddressManager() != address(0), "AddressManager is null in Parameters");
        // require worker to NOT have NOT VOTED MAX_SUCCEEDING_NOVOTES times in a row. If so, he has to wait NOVOTE_REGISTRATION_WAIT_DURATION
        require(
            !(// NOT
            worker_state.succeeding_novote_count >= Parameters.get_MAX_SUCCEEDING_NOVOTES() &&
                (block.timestamp - worker_state.registration_date) <
                Parameters.get_NOVOTE_REGISTRATION_WAIT_DURATION()),
            "User has not voted many times in a row and needs to wait NOVOTE_REGISTRATION_WAIT_DURATION to register again"
        );

        //_numTokens The number of tokens to be committed towards the target ArchiveData
        uint256 _numTokens = Parameters.get_ARCHIVING_MIN_STAKE();
        // Master/SubWorker Stake Management
        IAddressManager _AddressManager = IAddressManager(Parameters.getAddressManager());
        address _senderMaster = _AddressManager.getMaster(msg.sender); // detect if it's a master address, or a subaddress
        if (SystemStakedTokenBalance[msg.sender] < _numTokens) {
            // if not enough tokens allocated to this worksystem: check if master has some, or try to allocate
            if (_senderMaster != address(0)) {
                // if tx sender has a master, then interact with his master's stake
                if (SystemStakedTokenBalance[_senderMaster] < _numTokens) {
                    uint256 remainder = _numTokens.sub(SystemStakedTokenBalance[_senderMaster]);
                    requestAllocatedStake(remainder, _senderMaster);
                } // else, it's all good, master has enough allocated stake
            } else {
                uint256 remainder = _numTokens.sub(SystemStakedTokenBalance[msg.sender]);
                requestAllocatedStake(remainder, msg.sender);
            }
        }
        // make sure msg.sender has enough voting rights
        require(
            SystemStakedTokenBalance[msg.sender] >= _numTokens,
            "Worker has not enough (_numTokens) in his SystemStakedTokenBalance "
        );
        //////////////////////////////////
        if (!isInAvailableWorkers(msg.sender)) {
            availableWorkers.push(msg.sender);
        }
        worker_state.worker_address = msg.sender;
        worker_state.registered = true;
        worker_state.unregistration_request = false;
        worker_state.registration_date = block.timestamp;
        worker_state.succeeding_novote_count = 0; // reset the novote counter

        AllTxsCounter += 1;
        emit _WorkerRegistered(msg.sender, block.timestamp);
    }

    /* Unregister worker (offline) */
    function UnregisterWorker() public {
        WorkerState storage worker_state = WorkersState[msg.sender];
        require(worker_state.registered == true, "Worker is not registered so can't unregister");
        if (worker_state.allocated_work_batch != 0 && worker_state.unregistration_request == false) {
            worker_state.unregistration_request = true;
            toUnregisterWorkers.push(msg.sender);
        } else if (worker_state.allocated_work_batch == 0) {
            // only unregister a worker if he is not working
            //////////////////////////////////
            PopFromAvailableWorkers(msg.sender);
            PopFromBusyWorkers(msg.sender);
            worker_state.worker_address = msg.sender;
            worker_state.last_interaction_date = block.timestamp;
            worker_state.registered = false;
            emit _WorkerUnregistered(msg.sender, block.timestamp);
        }

        AllTxsCounter += 1;
        _retrieveSFuel();
    }

    function processLogoffRequests() internal {
        for (uint256 i = 0; i < toUnregisterWorkers.length; i++) {
            address worker_addr_ = toUnregisterWorkers[i];
            WorkerState storage worker_state = WorkersState[worker_addr_];
            if (worker_state.registered && worker_state.allocated_work_batch == 0) {
                worker_state.registered = false;
                worker_state.unregistration_request = false;
                PopFromAvailableWorkers(worker_addr_);
                PopFromBusyWorkers(worker_addr_);
            }
        }
        delete toUnregisterWorkers;
    }

    // ----------------------------------------------------------------------------------
    //                          LINK PREVIOUS DATA SPOTTING SYSTEM AS INPUT
    // ----------------------------------------------------------------------------------

    function Ping(uint256 CheckedBatchId) public {
        IPreviousSystem PreviousSystem = IPreviousSystem(Parameters.getComplianceSystem());
        if (Parameters.getComplianceSystem() != address(0) && !CollectedSpotBatchs[CheckedBatchId]) {
            // don't re import already collected batch

            if (PreviousSystem.DataExists(CheckedBatchId)) {
                IPreviousSystem.BatchMetadata memory SpotBatch = PreviousSystem.getBatchByID(CheckedBatchId);
                IPreviousSystem.DataStatus SpotBatchStatus = SpotBatch.status;
                // If SpotSystem has produced a new APPROVED DATA BATCH, process it in this system.
                if (SpotBatchStatus == IPreviousSystem.DataStatus.APPROVED) {
                    // -------- ADDING NEW CHECKED SPOT BATCH AS A NEW ITEM IN OUR ARCHIVING BATCH --------

                    ArchivesMapping[DataNonce] = ArchiveData({
                        ipfs_hash: SpotBatch.batchIPFSfile,
                        author: msg.sender,
                        timestamp: block.timestamp,
                        status: DataStatus.TBD
                    });

                    // UPDATE STREAMING DATA BATCH STRUCTURE
                    BatchMetadata storage current_data_batch = DataBatch[LastBatchCounter];
                    if (current_data_batch.counter < Parameters.get_ARCHIVING_DATA_BATCH_SIZE()) {
                        current_data_batch.counter += 1;
                    }
                    if (current_data_batch.counter >= Parameters.get_ARCHIVING_DATA_BATCH_SIZE()) {
                        // batch is complete trigger new work round, new batch
                        current_data_batch.complete = true;
                        current_data_batch.checked = false;
                        LastBatchCounter += 1;
                        DataBatch[LastBatchCounter].start_idx = DataNonce;
                    }

                    TriggerUpdate();
                    DataNonce = DataNonce + 1;
                    emit _ArchiveSubmitted(DataNonce, SpotBatch.batchIPFSfile, msg.sender);
                }
                // }
                CollectedSpotBatchs[CheckedBatchId] = true;
            }
        }
        AllTxsCounter += 1;
    }

    // ----------------------------------------------------------------------------------
    //                          UPDATE SYSTEMS
    // ----------------------------------------------------------------------------------

    function TriggerUpdate() public topUpSFuel {
        // Log off waiting users first
        if (toUnregisterWorkers.length > 0) {
            processLogoffRequests();
        }
        // Delete old data if needed
        deleteOldData();
        for (uint256 i = 0; i < Parameters.get_MAX_UPDATE_ITERATIONS(); i++) {
            bool progress = false;
            // IF CURRENT BATCH IS ALLOCATED TO WORKERS AND VOTE HAS ENDED, THEN CHECK IT & MOVE ON!
            if (
                DataBatch[BatchCheckingCursor].allocated_to_work == true &&
                (DataEnded(BatchCheckingCursor) || (DataBatch[BatchCheckingCursor].unrevealed_workers == 0))
            ) {
                ValidateDataBatch(BatchCheckingCursor);
                BatchCheckingCursor = BatchCheckingCursor.add(1);
                progress = true;
            }
            // IF CURRENT BATCH IS COMPLETE AND NOT ALLOCATED TO WORKERS TO BE CHECKED, THEN ALLOCATE!
            if (
                DataBatch[AllocatedBatchCursor].allocated_to_work != true &&
                availableWorkers.length >= Parameters.get_ARCHIVING_MIN_CONSENSUS_WORKER_COUNT() &&
                LastRandomSeed != getRandom() && // make sure randomness is refreshed
                DataBatch[AllocatedBatchCursor].complete
            ) {
                //nothing to allocate, waiting for this to end
                AllocateWork();
                progress = true;
            }
            if (!progress) {
                // break from the loop if no more progress is made when iterating (no batch to validate, no work to allocate)
                break;
            }
        }
    }

    function AreStringsEqual(string memory _a, string memory _b) public pure returns (bool) {
        if (keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b))) {
            return true;
        } else {
            return false;
        }
    }

    event BytesFailure(bytes bytesFailure);

    /**
    @notice Trigger the validation of a ArchiveData hash; if the ArchiveData has ended. If the requirements are APPROVED, 
    the CheckedData will be added to the APPROVED list of SpotCheckings
    @param _DataBatchId Integer identifier associated with target ArchiveData
    */
    function ValidateDataBatch(uint256 _DataBatchId) public {
        require(Parameters.getAddressManager() != address(0), "AddressManager is null in Parameters");
        require(Parameters.getRepManager() != address(0), "RepManager is null in Parameters");
        require(Parameters.getRewardManager() != address(0), "RewardManager is null in Parameters");
        require(
            DataEnded(_DataBatchId) || (DataBatch[_DataBatchId].unrevealed_workers == 0),
            "_DataBatchId has not ended, or not every voters have voted"
        ); // votes needs to be closed
        require(DataBatch[_DataBatchId].checked == false, "_DataBatchId is already validated"); // votes needs to be closed
        address[] memory allocated_workers_ = WorkersPerBatch[_DataBatchId];
        string[] memory proposedNewFiles = new string[](allocated_workers_.length);
        uint256[] memory proposedBatchCounts = new uint256[](allocated_workers_.length);

        // -------------------------------------------------------------
        // GATHER USER SUBMISSIONS AND VOTE INPUTS BEFORE ASSESSMENT
        for (uint256 i = 0; i < allocated_workers_.length; i++) {
            address worker_addr_ = allocated_workers_[i];
            string memory worker_proposed_new_file_ = UserNewFiles[_DataBatchId][worker_addr_];
            uint256 worker_proposed_new_count_ = UserBatchCounts[_DataBatchId][worker_addr_];
            proposedNewFiles[i] = worker_proposed_new_file_;
            proposedBatchCounts[i] = worker_proposed_new_count_;
        }

        // -------------------------------------------------------------
        // GET THE MAJORITY NEW HASH IPFS FILE
        uint256 majority_min_count = Math.max((allocated_workers_.length * Parameters.getVoteQuorum()) / 100, 1);

        string memory majorityNewFile = proposedNewFiles[0]; //take first file by default, just in case
        for (uint256 k = 0; k < proposedNewFiles.length; k++) {
            // count if this given New File is submitted by a majority
            uint256 counter = 0;
            for (uint256 l = 0; l < proposedNewFiles.length; l++) {
                if (AreStringsEqual(proposedNewFiles[k], proposedNewFiles[l])) {
                    counter += 1;
                    if (counter >= majority_min_count) {
                        break;
                    }
                }
            }
            if (counter >= majority_min_count) {
                majorityNewFile = proposedNewFiles[k];
                break;
            }
        }

        // GET THE MAJORITY BATCH COUNT
        uint256 majorityBatchCount = proposedBatchCounts[0]; //take first file by default, just in case
        for (uint256 k = 0; k < proposedBatchCounts.length; k++) {
            // count if this given New File is submitted by a majority
            uint256 counter = 0;
            for (uint256 l = 0; l < proposedBatchCounts.length; l++) {
                if (proposedBatchCounts[k] == proposedBatchCounts[l]) {
                    counter += 1;
                    if (counter >= majority_min_count) {
                        break;
                    }
                }
            }
            if (counter >= majority_min_count) {
                majorityBatchCount = proposedBatchCounts[k];
                break;
            }
        }

        // -------------------------------------------------------------
        // ASSESS VOTE RESULT AND REWARD USERS ACCORDINGLY
        for (uint256 i = 0; i < allocated_workers_.length; i++) {
            address worker_addr_ = allocated_workers_[i];
            bool has_worker_voted_ = UserChecksReveals[worker_addr_][_DataBatchId];

            // Worker state update
            //// because was busy a task, remove the worker from the busy pool
            PopFromBusyWorkers(worker_addr_);
            WorkerState storage worker_state = WorkersState[worker_addr_];

            if (has_worker_voted_) {
                // mark that worker has completed job, no matter the reward
                WorkersState[worker_addr_].has_completed_work = true;
                WorkersState[worker_addr_].succeeding_novote_count = 0; // reset the novote counter

                // then assess if worker is in the majority to reward or not
                string memory worker_proposed_hash = UserNewFiles[_DataBatchId][worker_addr_];
                if (AreStringsEqual(worker_proposed_hash, majorityNewFile)) {
                    IAddressManager _AddressManager = IAddressManager(Parameters.getAddressManager());
                    IRepManager _RepManager = IRepManager(Parameters.getRepManager());
                    IRewardManager _RewardsManager = IRewardManager(Parameters.getRewardManager());

                    address worker_master_addr_ = _AddressManager.FetchHighestMaster(worker_addr_); // detect if it's a master address, or a subaddress
                    require(
                        _RepManager.mintReputationForWork(
                            Parameters.get_ARCHIVING_MIN_REP_DataValidation() * majorityBatchCount,
                            worker_master_addr_,
                            ""
                        ),
                        "could not reward REP in ValidateDataBatch, 1.a"
                    );
                    require(
                        _RewardsManager.ProxyAddReward(
                            Parameters.get_ARCHIVING_MIN_REWARD_DataValidation() * majorityBatchCount,
                            worker_master_addr_
                        ),
                        "could not reward token in ValidateDataBatch, 1.b"
                    );
                    worker_state.majority_counter += 1;
                } else {
                    worker_state.minority_counter += 1;
                }

                // mark worker back available, removed from the busy list, if the worker has not requested unregistration
                if (worker_state.registered) {
                    // only if the worker is still registered, of course.
                    if (!isInAvailableWorkers(worker_addr_) && (worker_state.unregistration_request == false)) {
                        availableWorkers.push(worker_addr_);
                    }
                }
            }
            // if worker has not voted, he is disconnected "by force" OR if asked to be unregistered
            // this worker will have to register again
            else if (worker_state.unregistration_request || (has_worker_voted_ == false)) {
                WorkersState[worker_addr_].succeeding_novote_count += 1; // worker has not voted, increase the counter
                if (WorkersState[worker_addr_].succeeding_novote_count == Parameters.get_MAX_SUCCEEDING_NOVOTES()) {
                    // only if the worker is still registered
                    worker_state.registered = false;
                    PopFromAvailableWorkers(worker_addr_);
                    PopFromBusyWorkers(worker_addr_);
                }
            }
            // General Worker State Update
            worker_state.allocated_work_batch == 0;
        }
        // -------------------------------------------------------------
        // BATCH STATE UPDATE: mark it checked, final.
        DataBatch[_DataBatchId].checked = true;
        DataBatch[_DataBatchId].batchIPFSfile = majorityNewFile;
        DataBatch[_DataBatchId].item_count = majorityBatchCount;

        // -------------------------------------------------------------
        // IF THE DATA BLOCK IS ACCEPTED, MARK IT THAT WAY
        if (isPassed(_DataBatchId)) {
            DataBatch[_DataBatchId].status = DataStatus.APPROVED;
            AcceptedBatchsCounter += 1;
        }
        // -------------------------------------------------------------
        // IF THE DATA BLOCK IS REJECTED
        else {
            DataBatch[_DataBatchId].status = DataStatus.REJECTED;
            RejectedBatchsCounter += 1;
        }

        // ---------------- GLOBAL STATE UPDATE ----------------
        AllTxsCounter += 1;
        NotCommitedCounter += DataBatch[_DataBatchId].uncommited_workers;
        NotRevealedCounter += DataBatch[_DataBatchId].unrevealed_workers;

        emit _ArchiveAccepted(ArchivesMapping[_DataBatchId].ipfs_hash, ArchivesMapping[_DataBatchId].author);
    }

    /* 
    Allocate last data batch to be checked by K out N currently available workers.
     */
    function AllocateWork() public {
        require(DataBatch[AllocatedBatchCursor].complete, "Can't allocate work, the current batch is not complete");
        require(
            DataBatch[AllocatedBatchCursor].allocated_to_work == false,
            "Can't allocate work, the current batch is already allocated"
        );
        uint256 selected_k = Math.max(
            Math.min(availableWorkers.length, Parameters.get_ARCHIVING_MAX_CONSENSUS_WORKER_COUNT()),
            Parameters.get_ARCHIVING_MIN_CONSENSUS_WORKER_COUNT()
        ); // pick at most CONSENSUS_WORKER_SIZE workers, minimum 1.
        uint256 n = availableWorkers.length;

        ///////////////////////////// BATCH UPDATE STATE /////////////////////////////
        DataBatch[AllocatedBatchCursor].unrevealed_workers = selected_k;
        DataBatch[AllocatedBatchCursor].uncommited_workers = selected_k;

        uint256 _commitEndDate = block.timestamp.add(Parameters.get_ARCHIVING_COMMIT_ROUND_DURATION());
        uint256 _revealEndDate = _commitEndDate.add(Parameters.get_ARCHIVING_REVEAL_ROUND_DURATION());
        DataBatch[AllocatedBatchCursor].commitEndDate = _commitEndDate;
        DataBatch[AllocatedBatchCursor].revealEndDate = _revealEndDate;
        DataBatch[AllocatedBatchCursor].allocated_to_work = true;
        //////////////////////////////////////////////////////////////////////////////

        require(selected_k >= 1 && n >= 1, "Fail during allocation: not enough workers");
        uint256[] memory selected_workers_idx = random_selection(selected_k, n);
        address[] memory selected_workers_addresses = new address[](selected_workers_idx.length);
        for (uint256 i = 0; i < selected_workers_idx.length; i++) {
            selected_workers_addresses[i] = availableWorkers[selected_workers_idx[i]];
        }
        for (uint256 i = 0; i < selected_workers_idx.length; i++) {
            address selected_worker_ = selected_workers_addresses[i];
            WorkerState storage worker_state = WorkersState[selected_worker_];
            ///// worker swapping from available to busy, not to be picked again while working.
            PopFromAvailableWorkers(selected_worker_);
            if (!isInBusyWorkers(selected_worker_)) {
                busyWorkers.push(selected_worker_); //set worker as busy
            }
            WorkersPerBatch[AllocatedBatchCursor].push(selected_worker_);
            ///// allocation
            worker_state.allocated_work_batch = AllocatedBatchCursor;
            worker_state.has_completed_work = false;
            emit _WorkAllocated(AllocatedBatchCursor, selected_worker_);
        }
        AllocatedBatchCursor = AllocatedBatchCursor.add(1);
        LastRandomSeed = getRandom();
        AllTxsCounter += 1;
    }

    /* To know if new work is available for worker's address user_ */
    function IsNewWorkAvailable(address user_) public view returns (bool) {
        bool new_work_available = false;
        WorkerState memory user_state = WorkersState[user_];
        if (user_state.has_completed_work == false && DataEnded(user_state.allocated_work_batch) == false) {
            new_work_available = true;
        }
        return new_work_available;
    }

    /* Get newest work */
    function GetCurrentWork(address user_) public view returns (uint256) {
        WorkerState memory user_state = WorkersState[user_];
        return user_state.allocated_work_batch;
    }

    // ==============================================================================================================================
    // ====================================================== ARCHIVING  =============================================================
    // ==============================================================================================================================

    // =================
    // VOTING INTERFACE:
    // =================

    /**
    @notice Commits archive-check-vote using hash of choice and secret salt to conceal archive-check-vote until reveal
    @param _DataBatchId Integer identifier associated with target ArchiveData
    @param _secretIPFSHash ArchiveCheck HASH encrypted
    // @ _prevDataID The ID of the ArchiveData that the user has voted the maximum number of tokens in which is still less than or equal to numTokens
    */
    function commitArchiveCheck(
        uint256 _DataBatchId,
        bytes32 _secretIPFSHash,
        uint256 _BatchCount,
        string memory _From,
        string memory _Status
    ) public topUpSFuel {
        require(commitPeriodActive(_DataBatchId), "commit period needs to be open");
        require(!UserChecksCommits[msg.sender][_DataBatchId], "User has already commited to this batchId");
        require(
            isWorkerAllocatedToBatch(_DataBatchId, msg.sender),
            "User needs to be allocated to this batch to commit on it"
        );

        //_numTokens The number of tokens to be committed towards the target ArchiveData
        uint256 _numTokens = Parameters.get_ARCHIVING_MIN_STAKE();

        // Master/SubWorker Stake Management
        IAddressManager _AddressManager = IAddressManager(Parameters.getAddressManager());
        address _senderMaster = _AddressManager.getMaster(msg.sender); // detect if it's a master address, or a subaddress
        if (SystemStakedTokenBalance[msg.sender] < _numTokens) {
            // if not enough tokens allocated to this worksystem: check if master has some, or try to allocate
            if (_senderMaster != address(0)) {
                // if tx sender has a master, then interact with his master's stake
                if (SystemStakedTokenBalance[_senderMaster] < _numTokens) {
                    uint256 remainder = _numTokens.sub(SystemStakedTokenBalance[_senderMaster]);
                    requestAllocatedStake(remainder, _senderMaster);
                } // else, it's all good, master has enough allocated stake
            } else {
                uint256 remainder = _numTokens.sub(SystemStakedTokenBalance[msg.sender]);
                requestAllocatedStake(remainder, msg.sender);
            }
        }

        // make sure msg.sender has enough voting rights
        require(
            SystemStakedTokenBalance[msg.sender] >= _numTokens,
            "user must have enough voting rights aka allocated stake"
        );

        uint256 _prevDataID = 0;

        // Check if _prevDataID exists in the user's DLL or if _prevDataID is 0
        require(
            _prevDataID == 0 || dllMap[msg.sender].contains(_prevDataID),
            "Error:  _prevDataID exists in the user's DLL or if _prevDataID is 0"
        );

        uint256 nextDataID = dllMap[msg.sender].getNext(_prevDataID);

        // edge case: in-place update
        if (nextDataID == _DataBatchId) {
            nextDataID = dllMap[msg.sender].getNext(_DataBatchId);
        }

        require(validPosition(_prevDataID, nextDataID, msg.sender, _numTokens), "not a valid position");
        dllMap[msg.sender].insert(_prevDataID, _DataBatchId, nextDataID);

        bytes32 UUID = attrUUID(msg.sender, _DataBatchId);

        store.setAttribute(UUID, "numTokens", _numTokens);
        store.setAttribute(UUID, "commitHash", uint256(_secretIPFSHash));
        UserBatchCounts[_DataBatchId][msg.sender] = _BatchCount;
        UserBatchFrom[_DataBatchId][msg.sender] = _From;
        UserSubmittedStatus[_DataBatchId][msg.sender] = _Status;

        // WORKER STATE UPDATE
        WorkerState storage worker_state = WorkersState[msg.sender];
        DataBatch[_DataBatchId].uncommited_workers = DataBatch[_DataBatchId].uncommited_workers.sub(1);
        worker_state.last_interaction_date = block.timestamp;
        UserChecksCommits[msg.sender][_DataBatchId] = true;

        AllTxsCounter += 1;
        emit _ArchiveCheckCommitted(_DataBatchId, _numTokens, msg.sender);
    }

    /**
    @notice Reveals archive-check-vote with choice and secret salt used in generating commitHash to attribute committed tokens
    @param _DataBatchId Integer identifier associated with target ArchiveData
    @param _voteOption ArchiveCheck choice used to generate commitHash for associated ArchiveData
    @param _clearIPFSHash ArchiveCheck HASH in clear
    @param _salt Secret number used to generate commitHash for associated ArchiveData
    */
    function revealArchiveCheck(
        uint256 _DataBatchId,
        uint256 _voteOption,
        string memory _clearIPFSHash,
        uint256 _salt
    ) public topUpSFuel {
        // Make sure the reveal period is active
        require(revealPeriodActive(_DataBatchId), "Reveal period not open for this DataID");
        require(UserChecksCommits[msg.sender][_DataBatchId], "User has not commited before, thus can't reveal");
        require(!UserChecksReveals[msg.sender][_DataBatchId], "User has already revealed, thus can't reveal");
        require(
            getEncryptedStringHash(_clearIPFSHash, _salt) == getCommitIPFSHash(msg.sender, _DataBatchId),
            "Could not match encrypted hash & clear hash with given inputs."
        ); // compare resultant hash from inputs to original commitHash

        uint256 numTokens = getNumTokens(msg.sender, _DataBatchId);

        if (_voteOption == 1) {
            // apply numTokens to appropriate ArchiveData choice
            DataBatch[_DataBatchId].votesFor += numTokens;
        } else {
            DataBatch[_DataBatchId].votesAgainst += numTokens;
        }

        // ----------------------- USER STATE UPDATE -----------------------
        dllMap[msg.sender].remove(_DataBatchId); // remove the node referring to this archive-check-vote upon reveal
        UserChecksReveals[msg.sender][_DataBatchId] = true;
        UserVotes[_DataBatchId][msg.sender] = _voteOption;
        UserNewFiles[_DataBatchId][msg.sender] = _clearIPFSHash;

        // ----------------------- WORKER STATE UPDATE -----------------------
        WorkerState storage worker_state = WorkersState[msg.sender];
        DataBatch[_DataBatchId].unrevealed_workers = DataBatch[_DataBatchId].unrevealed_workers.sub(1);
        worker_state.has_completed_work = true;
        worker_state.last_interaction_date = block.timestamp;

        // PUT BACK THE WORKER AS AVAILABLE
        PopFromBusyWorkers(msg.sender);
        if (worker_state.registered) {
            // if still registered
            if (!isInAvailableWorkers(msg.sender)) {
                availableWorkers.push(msg.sender);
            }
        }

        // Move directly to Validation if everyone revealed.
        if (DataBatch[_DataBatchId].unrevealed_workers == 0) {
            ValidateDataBatch(_DataBatchId);
        }

        AllTxsCounter += 1;
        emit _ArchiveCheckRevealed(
            _DataBatchId,
            numTokens,
            DataBatch[_DataBatchId].votesFor,
            DataBatch[_DataBatchId].votesAgainst,
            _voteOption,
            msg.sender
        );
    }

    // ================================================================================
    //                              STAKING & TOKEN INTERFACE
    // ================================================================================

    /**
    @notice Loads _numTokens ERC20 tokens into the voting contract for one-to-one voting rights
    @dev Assumes that msg.sender has approved voting contract to spend on their behalf
    @param _numTokens The number of votingTokens desired in exchange for ERC20 tokens
    */
    function requestAllocatedStake(uint256 _numTokens, address _user) internal {
        require(Parameters.getStakeManager() != address(0), "StakeManager is null in Parameters");
        IStakeManager _StakeManager = IStakeManager(Parameters.getStakeManager());
        require(
            _StakeManager.ProxyStakeAllocate(_numTokens, _user),
            "Could not request enough allocated stake, requestAllocatedStake"
        );
        SystemStakedTokenBalance[_user] += _numTokens;
        emit _StakeAllocated(_numTokens, _user);
    }

    /**
    @notice Withdraw _numTokens ERC20 tokens from the voting contract, revoking these voting rights
    @param _numTokens The number of ERC20 tokens desired in exchange for voting rights
    */
    function withdrawVotingRights(uint256 _numTokens) public {
        uint256 availableTokens = SystemStakedTokenBalance[msg.sender].sub(getLockedTokens(msg.sender));
        require(availableTokens >= _numTokens, "availableTokens should be >= _numTokens");

        IStakeManager _StakeManager = IStakeManager(Parameters.getStakeManager());
        require(
            _StakeManager.ProxyStakeDeallocate(_numTokens, msg.sender),
            "Could not withdrawVotingRights through ProxyStakeDeallocate"
        );
        SystemStakedTokenBalance[msg.sender] -= _numTokens;
        emit _VotingRightsWithdrawn(_numTokens, msg.sender);
    }

    function getMySystemTokenBalance() public view returns (uint256 tokens) {
        return (uint256(SystemStakedTokenBalance[msg.sender]));
    }

    function getSystemTokenBalance(address _user) public view returns (uint256 tokens) {
        return (uint256(SystemStakedTokenBalance[_user]));
    }

    function getAcceptedBatchesCount() public view returns (uint256 count) {
        return (uint256(AcceptedBatchsCounter));
    }

    function getRejectedBatchesCount() public view returns (uint256 count) {
        return (uint256(RejectedBatchsCounter));
    }

    /**
    @dev Unlocks tokens locked in unrevealed archive-check-vote where ArchiveData has ended
    @param _DataBatchId Integer identifier associated with the target ArchiveData
    */
    function rescueTokens(uint256 _DataBatchId) public {
        require(
            DataBatch[_DataBatchId].status == DataStatus.APPROVED,
            "given DataBatch should be APPROVED, and it is not"
        );
        require(dllMap[msg.sender].contains(_DataBatchId), "dllMap: does not cointain _DataBatchId for the msg sender");

        dllMap[msg.sender].remove(_DataBatchId);
        emit _TokensRescued(_DataBatchId, msg.sender);
    }

    /**
    @dev Unlocks tokens locked in unrevealed archive-check-votes where Datas have ended
    @param _DataBatchIDs Array of integer identifiers associated with the target Datas
    */
    function rescueTokensInMultipleDatas(uint256[] memory _DataBatchIDs) public {
        // loop through arrays, rescuing tokens from all
        for (uint256 i = 0; i < _DataBatchIDs.length; i++) {
            rescueTokens(_DataBatchIDs[i]);
        }
    }

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    //                              STATE Getters
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------------------------------------------------------------------------------

    function getIPFShashesForBatch(uint256 _DataBatchId) public view returns (string[] memory) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");
        BatchMetadata memory batch_ = DataBatch[_DataBatchId];
        uint256 batch_size = batch_.counter;

        string[] memory ipfs_hash_list = new string[](batch_size);

        for (uint256 i = 0; i < batch_size; i++) {
            uint256 k = batch_.start_idx + i;
            string memory ipfs_hash_ = ArchivesMapping[k].ipfs_hash;
            ipfs_hash_list[i] = ipfs_hash_;
        }

        return ipfs_hash_list;
    }

    function getStatusForBatch(uint256 _DataBatchId) public view returns (string[] memory) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        address[] memory allocated_workers_ = WorkersPerBatch[_DataBatchId];
        string[] memory status_list = new string[](allocated_workers_.length);

        for (uint256 i = 0; i < allocated_workers_.length; i++) {
            status_list[i] = UserSubmittedStatus[_DataBatchId][allocated_workers_[i]];
        }
        return status_list;
    }

    function getFromsForBatch(uint256 _DataBatchId) public view returns (string[] memory) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        address[] memory allocated_workers_ = WorkersPerBatch[_DataBatchId];
        string[] memory from_list = new string[](allocated_workers_.length);

        for (uint256 i = 0; i < allocated_workers_.length; i++) {
            from_list[i] = UserBatchFrom[_DataBatchId][allocated_workers_[i]];
        }
        return from_list;
    }

    function getVotesForBatch(uint256 _DataBatchId) public view returns (uint256[] memory) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        address[] memory allocated_workers_ = WorkersPerBatch[_DataBatchId];
        uint256[] memory votes_list = new uint256[](allocated_workers_.length);

        for (uint256 i = 0; i < allocated_workers_.length; i++) {
            votes_list[i] = UserVotes[_DataBatchId][allocated_workers_[i]];
        }
        return votes_list;
    }

    function getSubmittedFilesForBatch(uint256 _DataBatchId) public view returns (string[] memory) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        address[] memory allocated_workers_ = WorkersPerBatch[_DataBatchId];
        string[] memory files_list = new string[](allocated_workers_.length);

        for (uint256 i = 0; i < allocated_workers_.length; i++) {
            files_list[i] = UserNewFiles[_DataBatchId][allocated_workers_[i]];
        }
        return files_list;
    }

    function getActiveWorkersCount() public view returns (uint256 numWorkers) {
        return (uint256(availableWorkers.length + busyWorkers.length));
    }

    function getAvailableWorkersCount() public view returns (uint256 numWorkers) {
        return (uint256(availableWorkers.length));
    }

    function getBusyWorkersCount() public view returns (uint256 numWorkers) {
        return (uint256(busyWorkers.length));
    }

    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    //                              Data HELPERS
    // --------------------------------------------------------------------------------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------------------------------------------------------------------------------

    /**
    @dev Compares previous and next ArchiveData's committed tokens for sorting purposes
    @param _prevID Integer identifier associated with previous ArchiveData in sorted order
    @param _nextID Integer identifier associated with next ArchiveData in sorted order
    @param _voter Address of user to check DLL position for
    @param _numTokens The number of tokens to be committed towards the ArchiveData (used for sorting)
    @return APPROVED Boolean indication of if the specified position maintains the sort
    */
    function validPosition(
        uint256 _prevID,
        uint256 _nextID,
        address _voter,
        uint256 _numTokens
    ) public view returns (bool APPROVED) {
        bool prevValid = (_numTokens >= getNumTokens(_voter, _prevID));
        // if next is zero node, _numTokens does not need to be greater
        bool nextValid = (_numTokens <= getNumTokens(_voter, _nextID) || _nextID == 0);
        return prevValid && nextValid;
    }

    /**
    @param _DataBatchId Integer identifier associated with target ArchiveData
    @param _salt Arbitrarily chosen integer used to generate secretHash
    @return correctArchiveChecks Number of tokens voted for winning option
    */
    function getNumPassingTokens(
        address _voter,
        uint256 _DataBatchId,
        uint256 _salt
    ) public view returns (uint256 correctArchiveChecks) {
        require(DataEnded(_DataBatchId), "_DataBatchId checking vote must have ended");
        require(UserChecksReveals[_voter][_DataBatchId], "user must have revealed in this given Batch");

        uint256 winningChoice = isPassed(_DataBatchId) ? 1 : 0;
        bytes32 winnerHash = keccak256(abi.encodePacked(winningChoice, _salt));
        bytes32 commitHash = getCommitVoteHash(_voter, _DataBatchId);

        require(winnerHash == commitHash, "getNumPassingTokens: hashes must be equal");

        return getNumTokens(_voter, _DataBatchId);
    }

    /**
    @notice Trigger the validation of a ArchiveData hash; if the ArchiveData has ended. If the requirements are APPROVED, 
    the ArchiveChecking will be added to the APPROVED list of ArchiveCheckings
    @param _DataBatchId Integer identifier associated with target ArchiveData
    */
    function getTotalNumberOfArchiveChecks(uint256 _DataBatchId) public view returns (uint256 vc) {
        // Build ArchiveCheckings Struct
        uint256 token_vote_count = DataBatch[_DataBatchId].votesFor + DataBatch[_DataBatchId].votesAgainst;
        return token_vote_count;
    }

    /**
    @notice Determines if proposal has passed
    @dev Check if votesFor out of totalArchiveChecks exceeds votesQuorum (requires DataEnded)
    @param _DataBatchId Integer identifier associated with target ArchiveData
    */
    function isPassed(uint256 _DataBatchId) public view returns (bool passed) {
        // require(DataEnded(_DataBatchId), "Data Batch Checking commitee must have ended");

        BatchMetadata memory batch_ = DataBatch[_DataBatchId];
        return (100 * batch_.votesFor) > (Parameters.getVoteQuorum() * (batch_.votesFor + batch_.votesAgainst));
    }

    /**
    @notice Determines if ArchiveData is over
    @dev Checks isExpired for specified ArchiveData's revealEndDate
    @return ended Boolean indication of whether Dataing period is over
    */
    function DataEnded(uint256 _DataBatchId) public view returns (bool ended) {
        require(DataExists(_DataBatchId), "Data must exist");

        return isExpired(DataBatch[_DataBatchId].revealEndDate);
    }

    /**
    @notice getLastDataId
    @return DataId of the last Dataed a user started
    */
    function getLastDataId() public view returns (uint256 DataId) {
        return DataNonce;
    }

    /**
    @notice getLastBatchId
    @return LastBatchId of the last Dataed a user started
    */
    function getLastBatchId() public view returns (uint256 LastBatchId) {
        return LastBatchCounter;
    }

    /**
    @notice getLastBachDataId
    @return LastCheckedBatchId of the last Dataed a user started
    */
    function getLastCheckedBatchId() public view returns (uint256 LastCheckedBatchId) {
        return BatchCheckingCursor;
    }

    /**
    @notice getLastAllocatedBatchId
    @return LastAllocatedBatchId of the last Dataed a user started
    */
    function getLastAllocatedBatchId() public view returns (uint256 LastAllocatedBatchId) {
        return AllocatedBatchCursor;
    }

    /**
    @notice getCounter
    @return Counter of the last Dataed a user started
    */
    function getTxCounter() public view returns (uint256 Counter) {
        return AllTxsCounter;
    }

    /**
    @notice Determines DataCommitEndDate
    @return commitEndDate indication of whether Dataing period is over
    */
    function DataCommitEndDate(uint256 _DataBatchId) public view returns (uint256 commitEndDate) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        return DataBatch[_DataBatchId].commitEndDate;
    }

    /**
    @notice Determines DataRevealEndDate
    @return revealEndDate indication of whether Dataing period is over
    */
    function DataRevealEndDate(uint256 _DataBatchId) public view returns (uint256 revealEndDate) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        return DataBatch[_DataBatchId].revealEndDate;
    }

    /**
    @notice Checks if the commit period is still active for the specified SpottedData
    @dev Checks isExpired for the specified SpottedData's commitEndDate
    @param _DataBatchId Integer identifier associated with target SpottedData
    @return active Boolean indication of isCommitPeriodActive for target SpottedData
    */
    function commitPeriodActive(uint256 _DataBatchId) public view returns (bool active) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        return !isExpired(DataBatch[_DataBatchId].commitEndDate) && (DataBatch[_DataBatchId].uncommited_workers > 0);
    }

    /**
    @notice Checks if the reveal period is still active for the specified ArchiveData
    @dev Checks isExpired for the specified ArchiveData's revealEndDate
    @param _DataBatchId Integer identifier associated with target ArchiveData
    */
    function revealPeriodActive(uint256 _DataBatchId) public view returns (bool active) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        return !isExpired(DataBatch[_DataBatchId].revealEndDate) && !commitPeriodActive(_DataBatchId);
    }

    /**
    @dev Checks if user has committed for specified ArchiveData
    @param _voter Address of user to check against
    @param _DataBatchId Integer identifier associated with target ArchiveData
    @return committed Boolean indication of whether user has committed
    */
    function didCommit(address _voter, uint256 _DataBatchId) public view returns (bool committed) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        // return ArchivesMapping[_DataBatchId].didCommit[_voter];
        return UserChecksCommits[_voter][_DataBatchId];
    }

    /**
    @dev Checks if user has revealed for specified ArchiveData
    @param _voter Address of user to check against
    @param _DataBatchId Integer identifier associated with target ArchiveData
    @return revealed Boolean indication of whether user has revealed
    */
    function didReveal(address _voter, uint256 _DataBatchId) public view returns (bool revealed) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        // return ArchivesMapping[_DataBatchId].didReveal[_voter];
        return UserChecksReveals[_voter][_DataBatchId];
    }

    /**
    @dev Checks if a ArchiveData exists
    @param _DataBatchId The DataID whose existance is to be evaluated.
    @return exists Boolean Indicates whether a ArchiveData exists for the provided DataID
    */
    function DataExists(uint256 _DataBatchId) public view returns (bool exists) {
        return (_DataBatchId <= LastBatchCounter);
    }

    function AmIRegistered() public view returns (bool passed) {
        return WorkersState[msg.sender].registered;
    }

    function isWorkerRegistered(address _worker) public view returns (bool passed) {
        return WorkersState[_worker].registered;
    }

    /**
    @notice getLastBachDataId
    @return batch of the last Dataed a user started
    */
    function getBatchByID(uint256 _DataBatchId) public view returns (BatchMetadata memory batch) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");
        return DataBatch[_DataBatchId];
    }

    /**
    @notice getLastBachDataId
    @return batch of the last Dataed a user started
    */
    function getBatchIPFSFileByID(uint256 _DataBatchId) public view returns (string memory batch) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");
        return DataBatch[_DataBatchId].batchIPFSfile;
    }

    // return only accepted batches
    function getAcceptedBatchFilesRange(uint256 _DataBatchId_start, uint256 _DataBatchId_end)
        public
        view
        returns (string[] memory batch)
    {
        require(_DataBatchId_start < _DataBatchId_end, "_DataBatchId_start must be < than _DataBatchId_end");
        require(DataExists(_DataBatchId_end), "_DataBatchId_end must exist: the input range is not correct");
        uint256 list_size = _DataBatchId_end - _DataBatchId_start + 1;
        string[] memory file_list = new string[](list_size);
        for (uint256 i = _DataBatchId_start; i < _DataBatchId_end; i++) {
            if (DataBatch[i].status == DataStatus.APPROVED) {
                file_list[i] = DataBatch[i].batchIPFSfile;
            }
        }
        return file_list;
    }

    // return only accepted batches
    function getAcceptedBatchFileFrom(uint256 _DataBatchId_start) public view returns (string[] memory batch) {
        require(DataExists(_DataBatchId_start), "_DataBatchId_start must exist");
        uint256 list_size = BatchCheckingCursor - _DataBatchId_start + 1;
        string[] memory file_list = new string[](list_size);
        for (uint256 i = _DataBatchId_start; i < BatchCheckingCursor; i++) {
            if (DataBatch[i].status == DataStatus.APPROVED) {
                file_list[i] = DataBatch[i].batchIPFSfile;
            }
        }
        return file_list;
    }

    /**
    @notice getLastBachDataId
    @return data of the last Dataed a user started
    */
    function getDataByID(uint256 _DataId) public view returns (ArchiveData memory data) {
        return ArchivesMapping[_DataId];
    }

    // ------------------------------------------------------------------------------------------------------------
    // STORAGE AND DLL HELPERS:
    // ------------------------------------------------------------------------------------------------------------

    /**
    @dev Gets the bytes32 commitHash property of target SpottedData
    @param _voter Address of user to check against
    @param _DataBatchId Integer identifier associated with target SpottedData
    @return commitHash Bytes32 hash property attached to target SpottedData
    */
    function getCommitVoteHash(address _voter, uint256 _DataBatchId) public view returns (bytes32 commitHash) {
        return bytes32(store.getAttribute(attrUUID(_voter, _DataBatchId), "commitVote"));
    }

    /**
    @dev Gets the bytes32 commitHash property of target SpottedData
    @param _voter Address of user to check against
    @param _DataBatchId Integer identifier associated with target SpottedData
    @return commitHash Bytes32 hash property attached to target SpottedData
    */
    function getCommitIPFSHash(address _voter, uint256 _DataBatchId) public view returns (bytes32 commitHash) {
        return bytes32(store.getAttribute(attrUUID(_voter, _DataBatchId), "commitHash"));
    }

    /**
    @dev Gets the bytes32 commitHash property of target ArchiveData
    @param _hash ipfs hash of aggregated data in a string
    @param _salt is the salt
    @return keccak256hash Bytes32 hash property attached to target ArchiveData
    */
    function getEncryptedStringHash(string memory _hash, uint256 _salt) public pure returns (bytes32 keccak256hash) {
        return keccak256(abi.encode(_hash, _salt));
    }

    /**
    @dev Wrapper for getAttribute with attrName="numTokens"
    @param _voter Address of user to check against
    @param _DataBatchId Integer identifier associated with target ArchiveData
    @return numTokens Number of tokens committed to ArchiveData in sorted ArchiveData-linked-list
    */
    function getNumTokens(address _voter, uint256 _DataBatchId) public view returns (uint256 numTokens) {
        return store.getAttribute(attrUUID(_voter, _DataBatchId), "numTokens");
    }

    /**
    @dev Gets top element of sorted ArchiveData-linked-list
    @param _voter Address of user to check against
    @return DataID Integer identifier to ArchiveData with maximum number of tokens committed to it
    */
    function getLastNode(address _voter) public view returns (uint256 DataID) {
        return dllMap[_voter].getPrev(0);
    }

    /**
    @dev Gets the numTokens property of getLastNode
    @param _voter Address of user to check against
    @return numTokens Maximum number of tokens committed in ArchiveData specified
    */
    function getLockedTokens(address _voter) public view returns (uint256 numTokens) {
        return getNumTokens(_voter, getLastNode(_voter));
    }

    /*
    @dev Takes the last node in the user's DLL and iterates backwards through the list searching
    for a node with a value less than or equal to the provided _numTokens value. When such a node
    is found, if the provided _DataBatchId matches the found nodeID, this operation is an in-place
    update. In that case, return the previous node of the node being updated. Otherwise return the
    first node that was found with a value less than or equal to the provided _numTokens.
    @param _voter The voter whose DLL will be searched
    @param _numTokens The value for the numTokens attribute in the node to be inserted
    @return the node which the propoded node should be inserted after
    */
    function getInsertPointForNumTokens(
        address _voter,
        uint256 _numTokens,
        uint256 _DataBatchId
    ) public view returns (uint256 prevNode) {
        // Get the last node in the list and the number of tokens in that node
        uint256 nodeID = getLastNode(_voter);
        uint256 tokensInNode = getNumTokens(_voter, nodeID);

        // Iterate backwards through the list until reaching the root node
        while (nodeID != 0) {
            // Get the number of tokens in the current node
            tokensInNode = getNumTokens(_voter, nodeID);
            if (tokensInNode <= _numTokens) {
                // We found the insert point!
                if (nodeID == _DataBatchId) {
                    // This is an in-place update. Return the prev node of the node being updated
                    nodeID = dllMap[_voter].getPrev(nodeID);
                }
                // Return the insert point
                return nodeID;
            }
            // We did not find the insert point. Continue iterating backwards through the list
            nodeID = dllMap[_voter].getPrev(nodeID);
        }

        // The list is empty, or a smaller value than anything else in the list is being inserted
        return nodeID;
    }

    // ----------------
    // GENERAL HELPERS:
    // ----------------

    /**
    @dev Checks if an expiration date has been reached
    @param _terminationDate Integer timestamp of date to compare current timestamp with
    @return expired Boolean indication of whether the terminationDate has passed
    */
    function isExpired(uint256 _terminationDate) public view returns (bool expired) {
        return (block.timestamp > _terminationDate);
    }

    /**
    @dev Generates an identifier which associates a user and a ArchiveData together
    @param _DataBatchId Integer identifier associated with target ArchiveData
    @return UUID Hash which is deterministic from _user and _DataBatchId
    */
    function attrUUID(address _user, uint256 _DataBatchId) public pure returns (bytes32 UUID) {
        return keccak256(abi.encodePacked(_user, _DataBatchId));
    }
}
