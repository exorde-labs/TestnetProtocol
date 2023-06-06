// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

/**
 * @title WorkSystem Spot v1.3.4a
 * @author Mathias Dail - CTO @ Exorde Labs 2022
 */

// File: dll/DLL.sol

library DLL {
    uint128 constant NULL_NODE_ID = 0;

    struct Node {
        uint128 next;
        uint128 prev;
    }

    struct SpottedData {
        mapping(uint128 => Node) dll;
    }

    function isEmpty(SpottedData storage self) public view returns(bool) {
        return getStart(self) == NULL_NODE_ID;
    }

    function contains(SpottedData storage self, uint128 _curr) public view returns(bool) {
        if (isEmpty(self) || _curr == NULL_NODE_ID) {
            return false;
        }

        bool isSingleNode = (getStart(self) == _curr) && (getEnd(self) == _curr);
        bool isNullNode = (getNext(self, _curr) == NULL_NODE_ID) && (getPrev(self, _curr) == NULL_NODE_ID);
        return isSingleNode || !isNullNode;
    }

    function getNext(SpottedData storage self, uint128 _curr) public view returns(uint128) {
        return self.dll[_curr].next;
    }

    function getPrev(SpottedData storage self, uint128 _curr) public view returns(uint128) {
        return self.dll[_curr].prev;
    }

    function getStart(SpottedData storage self) public view returns(uint128) {
        return getNext(self, NULL_NODE_ID);
    }

    function getEnd(SpottedData storage self) public view returns(uint256) {
        return getPrev(self, NULL_NODE_ID);
    }

    /**
  * @dev Inserts a new node between _prev and _next. When inserting a node already existing in 
  the list it will be automatically removed from the old position.
  * @param _prev the node which _new will be inserted after
  * @param _curr the id of the new node being inserted
  * @param _next the node which _new will be inserted before
  */
    function insert(
        SpottedData storage self,
        uint128 _prev,
        uint128 _curr,
        uint128 _next
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

    function remove(SpottedData storage self, uint128 _curr) public {
        if (!contains(self, _curr)) {
            return;
        }

        uint128 next = getNext(self, _curr);
        uint128 prev = getPrev(self, _curr);

        self.dll[next].prev = prev;
        self.dll[prev].next = next;

        delete self.dll[_curr];
    }
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IReputation.sol";
import "./interfaces/IRepManager.sol";
import "./interfaces/IDataSpotting.sol";
import "./interfaces/IDataQuality.sol";
import "./interfaces/IRewardManager.sol";
import "./interfaces/IStakeManager.sol";
import "./interfaces/IAddressManager.sol";
import "./interfaces/IParametersManager.sol";
import "./RandomAllocator.sol";

/**
 * @title WorkSystem Spot v1.3.4a
 * @author Mathias Dail - CTO @ Exorde Labs
 */
contract DataSpotting is Ownable, RandomAllocator, Pausable, IDataSpotting {
    // ============ EVENTS ============
    event _SpotSubmitted(uint256 indexed DataID, string file_hash, string URL_domain, address indexed sender);
    event _StakeAllocated(uint256 numTokens, address indexed voter);
    event _VotingRightsWithdrawn(uint256 numTokens, address indexed voter);
    event _TokensRescued(uint256 indexed DataID, address indexed voter);
    event _DataBatchDeleted(uint256 indexed batchID);
    event ParametersUpdated(address parameters);
    event BytesFailure(bytes bytesFailure);

    // ============ LIBRARIES ============
    // using AttributeStore for AttributeStore.SpottedData;
    using DLL
    for DLL.SpottedData;

    // ============ DATA STRUCTURES ============


    // ====================================
    //        GLOBAL STATE VARIABLES
    // ====================================

    // ------ Spotting input flow management
    uint64 public LastAllocationTime = 0;
    uint16 constant NB_TIMEFRAMES = 15;
    uint16 constant MAX_MASTER_DEPTH = 3;
    TimeframeCounter[NB_TIMEFRAMES] public GlobalSpotFlowManager; // NB_TIMEFRAMES*2 slots
    TimeframeCounter[NB_TIMEFRAMES] public ItemFlowManager; // NB_TIMEFRAMES*2 slots per user

    // ------ User Submissions
    address[] public AllWorkersList;

    // ------ Backend Data Stores
    mapping(bytes32 => uint256) store;
    mapping(uint128 => SpottedData) public SpotsMapping; // maps DataID to SpottedData struct
    mapping(uint128 => BatchMetadata) public DataBatch; // refers to SpottedData indices

    // ------ Worker & Stake related structure
    mapping(address => DLL.SpottedData) private dllMap;
    mapping(address => WorkerState) public WorkersState;
    mapping(address => TimeframeCounter[NB_TIMEFRAMES]) public WorkersSpotFlowManager;
    mapping(address => uint256) public SystemStakedTokenBalance; // maps user's address to voteToken balance

    // ------ Worker management structures
    mapping(address => WorkerStatus) public WorkersStatus;

    // ------ Processes counters
    uint128 public DataNonce = 0;
    // -- Batches Counters
    uint128 public LastBatchCounter = 1;
    uint128 public BatchDeletionCursor = 1;

    // ------ Statistics related counters
    uint256 public LastRandomSeed = 0;
    uint256 public AllTxsCounter = 0;
    uint256 public AllItemCounter = 0;

    // ------ STORAGE SPACE COUNTERS
    uint256 constant BYTES_256 = 32;
    uint256 constant BYTES_128 = 16;
    uint256 constant BYTES_64 = 8;
    uint256 constant BYTES_32 = 4;
    uint256 constant BYTES_16 = 2;
    uint256 constant BYTES_8 = 1;
    // Initial storage variables =  Approx. 404 bytes.
    uint256 public BytesUsed = 404;

    uint128 public MAX_INDEX_RANGE_BATCHS = 10000;
    uint128 public MAX_INDEX_RANGE_SPOTS = 10000 * 30;

    // ------ Vote related    
    uint16 constant APPROVAL_VOTE_MAPPING_ = 1;
    uint16 immutable MAX_WORKER_ALLOCATED_PER_BATCH = 30;

    // ------------ Rewards & Work allocation related
    bool public STAKING_REQUIREMENT_TOGGLE_ENABLED = false;
    bool public VALIDATE_ON_LAST_REVEAL = false;
    bool public FORCE_VALIDATE_BATCH_FILE = true;
    bool public InstantSpotRewards = true;
    uint16 public InstantSpotRewardsDivider = 30;
    uint256 public NB_BATCH_TO_TRIGGER_GARBAGE_COLLECTION = 1000;
    uint256 private MIN_OFFSET_DELETION_CURSOR = 50;

    // ---------------------

    // ------ Addresses & Interfaces
    IERC20 public token;
    IParametersManager public Parameters;

    // ================================================================================
    //                             Constructor
    // ================================================================================

    /**
     * @dev Initializer. Can only be called once.
     */
    constructor(address EXDT_token_) {
        require(address(EXDT_token_) != address(0));
        token = IERC20(EXDT_token_);
    }

    // ================================================================================
    //                             Management & Administration
    // ================================================================================

    /**
     * @notice Pause or unpause the contract
     */
    function toggleSystemPause() public onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }

    /**
     * @notice Updates Parameters Manager
     * @param addr address of the Parameter Contract
     */
    function updateParametersManager(address addr) public onlyOwner {
        require(addr != address(0), "addr must be non zero");
        Parameters = IParametersManager(addr);
        emit ParametersUpdated(addr);
    }


    // ================================================================================
    //                             ADMIN Updaters
    // ================================================================================

    /**
     * @notice Enable or disable instant rewards when SpottingData (Testnet)
     * @param state_ boolean
     * @param divider_ base rewards divider
     */
    function updateInstantSpotRewards(bool state_, uint16 divider_) public onlyOwner {
        InstantSpotRewards = state_;
        InstantSpotRewardsDivider = divider_;
    }

    /**
     * @notice update MaxPendingDataBatchCount, limiting the queue of data to validate
     * @param NewGarbageCollectTreshold_ new threshold for deletion of batchs data
     */
    function updateGarbageCollectionThreshold(uint256 NewGarbageCollectTreshold_) public onlyOwner {
        require(NewGarbageCollectTreshold_ > 100, "NewGarbageCollectTreshold_ must be > 100");
        NB_BATCH_TO_TRIGGER_GARBAGE_COLLECTION = NewGarbageCollectTreshold_;
    }



    // ================================================================================
    //                             Library Related
    // ================================================================================

    /**
     * @notice getAttribute from UUID and attrName
     * @param _UUID unique identifier
     * @param _attrName name of the attribute
     */
    function getAttribute(bytes32 _UUID, string memory _attrName) public view returns(uint256) {
        bytes32 key = keccak256(abi.encodePacked(_UUID, _attrName));
        return store[key];
    }

    /**
     * @notice setAttribute from UUID , attrName & attrVal
     * @param _UUID unique identifier
     * @param _attrName name of the attribute
     * @param _attrVal value of the attribute
     */
    function setAttribute(
        bytes32 _UUID,
        string memory _attrName,
        uint256 _attrVal
    ) internal {
        bytes32 key = keccak256(abi.encodePacked(_UUID, _attrName));
        store[key] = _attrVal;

    }

    /**
     * @notice resetAttribute
     * @param _UUID unique identifier
     * @param _attrName name of the attribute
     */
    function resetAttribute(
        bytes32 _UUID,
        string memory _attrName
    ) internal {
        bytes32 key = keccak256(abi.encodePacked(_UUID, _attrName));
        delete store[key];
    }

    // ================================================================================
    //                              sFuel (eth) Auto Top Up system
    // ================================================================================

    /**
     * @notice Refill the msg.sender with sFuel. Skale gasless "gas station network" equivalent
     */
    function _retrieveSFuel() internal {
        require(IParametersManager(address(0)) != Parameters, "Parameters Manager must be set.");
        address sFuelAddress;
        sFuelAddress = Parameters.getsFuelSystem();
        require(sFuelAddress != address(0), "sFuel: null Address Not Valid");
        (bool success1, ) = sFuelAddress.call(abi.encodeWithSignature("retrieveSFuel(address)", payable(msg.sender)));
        (bool success2, ) = sFuelAddress.call(
            abi.encodeWithSignature("retrieveSFuel(address payable)", payable(msg.sender))
        );
        require((success1 || success2), "receiver rejected _retrieveSFuel call");
    }

    // ================================================================================
    //                         WORKER REGISTRATION & LOBBY MANAGEMENT
    // ================================================================================

    /** @notice returns BatchId modulo MAX_INDEX_RANGE_BATCHS
     */
    function _ModB(uint128 BatchId) private view returns(uint128) {
        return BatchId % MAX_INDEX_RANGE_BATCHS;
    }

    /** @notice returns SpotId modulo MAX_INDEX_RANGE_SPOTS
     */
    function _ModS(uint128 SpotId) private view returns(uint128) {
        return SpotId % MAX_INDEX_RANGE_SPOTS;
    }


    /* 
        Select Address for a worker address, between itself and a potential Master Address    
    Crawl up the tree of master (depth can be max 3: worker -> master-worker -> main address)
    */
    function SelectAddressForUser(address _worker, uint256 _TokensAmountToAllocate) public view returns(address) {
        require(IParametersManager(address(0)) != Parameters, "Parameters Manager must be set.");
        require(Parameters.getAddressManager() != address(0), "AddressManager is null in Parameters");
        require(Parameters.getStakeManager() != address(0), "StakeManager is null in Parameters");
        IStakeManager _StakeManager = IStakeManager(Parameters.getStakeManager());
        IAddressManager _AddressManager = IAddressManager(Parameters.getAddressManager());

        address _SelectedAddress = _worker;
        address _CurrentAddress = _worker;

        for (uint256 i = 0; i < MAX_MASTER_DEPTH; i++) {
            // check if _CurrentAddress has enough available stake
            uint256 _CurrentAvailableStake = _StakeManager.AvailableStakedAmountOf(_CurrentAddress);

            // Case 1 : the _CurrentAddress has enough staked in the system already, then good.
            if (SystemStakedTokenBalance[_CurrentAddress] >= _TokensAmountToAllocate) {
                // Found enough Staked in the system already, return this address
                _SelectedAddress = _CurrentAddress;
                break;
            }
            // Case 2 : the _CurrentAddress has partially enough staked in the system already
            else if (
                SystemStakedTokenBalance[_CurrentAddress] <= _TokensAmountToAllocate &&
                SystemStakedTokenBalance[_CurrentAddress] > 0
            ) {
                uint256 remainderAmountToAllocate = _TokensAmountToAllocate -
                    SystemStakedTokenBalance[_CurrentAddress];
                if (_CurrentAvailableStake >= remainderAmountToAllocate) {
                    // There is enough in the AvailableStake to allocate, return this address
                    _SelectedAddress = _CurrentAddress;
                    break;
                }
            }
            // Case 3 : the _CurrentAddress enough to allocate on StakeManager for the given amount
            if (_CurrentAvailableStake >= _TokensAmountToAllocate) {
                // There is enough in the AvailableStake to allocate, return this address
                _SelectedAddress = _CurrentAddress;
                break;
            }

            _CurrentAddress = _AddressManager.getMaster(_CurrentAddress);

            if (_CurrentAddress == address(0)) {
                break; // quit the loop if we reached a "top" in the tree search
            }
        }

        return _SelectedAddress;
    }

    function IsAddressKicked(address user_) public view returns(bool status) {
        bool status_ = false;
        WorkerState memory worker_state = WorkersState[user_];
        if ((worker_state.succeeding_novote_count >= Parameters.get_MAX_SUCCEEDING_NOVOTES() &&
                ((block.timestamp - worker_state.registration_date) <
                    Parameters.get_NOVOTE_REGISTRATION_WAIT_DURATION()))) {
            status_ = true;
        }
        return status_;
    }

    function AmIKicked() public view returns(bool status) {
        return IsAddressKicked(msg.sender);
    }

    // Handle staking requirements for the worker
    // -> Master/SubWorker Stake Management
    // -> _numTokens The number of tokens to be allocated
    function handleStakingRequirement(address worker) internal {
        if (STAKING_REQUIREMENT_TOGGLE_ENABLED) {
            uint256 _numTokens = Parameters.get_SPOT_MIN_STAKE();
            address _selectedAddress = SelectAddressForUser(worker, _numTokens);

            // if tx sender has a master, then interact with his master's stake, or himself
            if (SystemStakedTokenBalance[_selectedAddress] < _numTokens) {
                uint256 remainder = _numTokens - SystemStakedTokenBalance[_selectedAddress];
                requestAllocatedStake(remainder, _selectedAddress);
            }
        }
    }


    // ================================================================================	
    //                             Data Deletion Function	
    // ================================================================================	

    /**	
     * @notice Delete Data	
     */
    function deleteOldData(uint128 iteration_count) internal {
        // Rolling delete of previous data	
        uint128 _deletion_index;
        // make the system store at least this many batchs (offset between DeletionCursor & CheckingCursor)
        if ((BatchDeletionCursor < (LastBatchCounter - MIN_OFFSET_DELETION_CURSOR))) {
            // Here the amount of iterations is capped by get_MAX_UPDATE_ITERATIONS	
            for (uint128 i = 0; i < iteration_count; i++) {
                _deletion_index = BatchDeletionCursor;
                // First Delete Atomic Data composing the Batch, from start to end indices	
                uint128 start_batch_idx = DataBatch[_ModB(_deletion_index)].start_idx;
                uint128 end_batch_idx = DataBatch[_ModB(_deletion_index)].start_idx +
                    DataBatch[_ModB(_deletion_index)].counter;
                for (uint128 l = start_batch_idx; l < end_batch_idx; l++) {
                    delete SpotsMapping[_ModS(l)]; // delete SpotsMapping at index l                    
                }
                // delete the batch	
                delete DataBatch[_ModB(_deletion_index)];
                emit _DataBatchDeleted(_deletion_index);
                // Update Global Variable	
                BatchDeletionCursor = BatchDeletionCursor + 1;
            }
        }
    }


    /**
     * @dev Destroy AllWorkersArray, important to release storage space if critical
     */
    function deleteWorkersAtIndex(uint256 index_) public onlyOwner {
        address worker_at_index = AllWorkersList[index_];
        address SwappedWorkerAtIndex = AllWorkersList[AllWorkersList.length - 1];
        if (AllWorkersList.length >= 2) {
            AllWorkersList[index_] = SwappedWorkerAtIndex; // swap last worker to this new position
        }

        AllWorkersList.pop(); // pop last worker         
        deleteWorkersStatus(worker_at_index);

        //----- Track Storage usage -----
        uint256 BytesUsedReduction = BYTES_256;
        if (BytesUsed >= BytesUsedReduction) {
            BytesUsed -= BytesUsedReduction;
        } else {
            BytesUsed = 0;
        }
    }

    /**
     * @dev Destroy WorkersStatus for users_ array, important to release storage space if critical
     */
    function deleteManyWorkersAtIndex(uint256[] memory indices_) public onlyOwner {
        for (uint256 i = 0; i < indices_.length; i++) {
            uint256 _index = indices_[i];
            deleteWorkersAtIndex(_index);
        }

    }
    /**
     * @dev Destroy WorkersStatus, important to release storage space if critical
     */
    function deleteWorkersStatus(address user_) public onlyOwner {
        delete WorkersStatus[user_];
        //----- Track Storage usage -----
        uint256 BytesUsedReduction = BYTES_256;
        if (BytesUsed >= BytesUsedReduction) {
            BytesUsed -= BytesUsedReduction;
        } else {
            BytesUsed = 0;
        }
        //----- Track Storage usage -----
    }


    /**
     * @dev Destroy WorkersStatus for users_ array, important to release storage space if critical
     */
    function deleteManyWorkersStatus(address[] memory users_) public onlyOwner {
        for (uint256 i = 0; i < users_.length; i++) {
            address _user = users_[i];
            deleteWorkersStatus(_user);
        }
    }

    /**
     * @dev Destroy WorkersState, important to release storage space if critical
     */
    function deleteWorkersState(address user_) public onlyOwner {
        delete WorkersState[user_];
        delete dllMap[user_];
        delete WorkersSpotFlowManager[user_];
        delete SystemStakedTokenBalance[user_];
        //----- Track Storage usage -----
        uint256 BytesUsedReduction = BYTES_256 * (2 + 1 + 15 * 2 + 1);
        if (BytesUsed >= BytesUsedReduction) {
            BytesUsed -= BytesUsedReduction;
        } else {
            BytesUsed = 0;
        }
        //----- Track Storage usage -----
    }

    /**
     * @dev Destroy WorkersStatus for users_ array, important to release storage space if critical
     */
    function deleteManyWorkersState(address[] memory users_) public onlyOwner {
        for (uint256 i = 0; i < users_.length; i++) {
            address _user = users_[i];
            deleteWorkersState(_user);
        }
    }

    // ================================================================================
    //                             Trigger State Update : Public
    // ================================================================================


    /**
     * @notice Trigger spot flow management
     */
    function TriggerUpdate() public {
        require(IParametersManager(address(0)) != Parameters, "Parameters Manager must be set.");
        // Update the Spot Flow System
        updateGlobalSpotFlow();
        _retrieveSFuel();
    }



    /**
     * @notice Checks if two strings are equal
     * @param _a string
     * @param _b string
     */
    function AreStringsEqual(string memory _a, string memory _b) public pure returns(bool) {
        if (keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b))) {
            return true;
        } else {
            return false;
        }
    }


    // ================================================================================
    //                             INPUT DATA FLOW MANAGEMENT
    // ================================================================================

    /**
     * @notice Update the global sliding counter of spotted data, measuring the spots per TIMEFRAME (hour)
     */
    function updateGlobalSpotFlow() public {
        require(IParametersManager(address(0)) != Parameters, "Parameters Manager must be set.");
        uint256 last_timeframe_idx_ = GlobalSpotFlowManager.length - 1;
        uint256 mostRecentTimestamp_ = GlobalSpotFlowManager[last_timeframe_idx_].timestamp;
        if ((uint64(block.timestamp) - mostRecentTimestamp_) > Parameters.get_SPOT_TIMEFRAME_DURATION()) {
            // cycle & move periods to the left
            for (uint256 i = 0; i < (GlobalSpotFlowManager.length - 1); i++) {
                GlobalSpotFlowManager[i] = GlobalSpotFlowManager[i + 1];
            }
            //update last timeframe with new values & reset counter
            GlobalSpotFlowManager[last_timeframe_idx_].timestamp = uint64(block.timestamp);
            GlobalSpotFlowManager[last_timeframe_idx_].counter = 0;
        }
    }

    /**
     * @notice Count the total spots per TIMEFRAME (hour)
     */
    function getGlobalPeriodSpotCount() public view returns(uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < GlobalSpotFlowManager.length; i++) {
            total += GlobalSpotFlowManager[i].counter;
        }
        return total;
    }


    /**
     * @notice Count the total spots per TIMEFRAME (hour)
     */
    function getPeriodItemCount() public view returns(uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < ItemFlowManager.length; i++) {
            total += ItemFlowManager[i].counter;
        }
        return total;
    }

    /**
     * @notice Update the total spots per TIMEFRAME (hour) per USER
     * @param user_ user
     */
    function updateUserSpotFlow(address user_) public {
        require(IParametersManager(address(0)) != Parameters, "Parameters Manager must be set.");
        TimeframeCounter[NB_TIMEFRAMES] storage UserSpotFlowManager = WorkersSpotFlowManager[user_];

        uint256 last_timeframe_idx_ = UserSpotFlowManager.length - 1;
        uint256 mostRecentTimestamp_ = UserSpotFlowManager[last_timeframe_idx_].timestamp;
        if ((block.timestamp - mostRecentTimestamp_) > Parameters.get_SPOT_TIMEFRAME_DURATION()) {
            // cycle & move periods to the left
            for (uint256 i = 0; i < (UserSpotFlowManager.length - 1); i++) {
                UserSpotFlowManager[i] = UserSpotFlowManager[i + 1];
            }
            //update last timeframe with new values & reset counter
            UserSpotFlowManager[last_timeframe_idx_].timestamp = uint64(block.timestamp);
            UserSpotFlowManager[last_timeframe_idx_].counter = 0;
        }
    }

    /**
     * @notice Count the total spots per TIMEFRAME (hour) per USER
     * @param user_ user
     */
    function getUserPeriodSpotCount(address user_) public view returns(uint256) {
        TimeframeCounter[NB_TIMEFRAMES] storage UserSpotFlowManager = WorkersSpotFlowManager[user_];
        uint256 total = 0;
        for (uint256 i = 0; i < UserSpotFlowManager.length; i++) {
            total += UserSpotFlowManager[i].counter;
        }
        return total;
    }

    // ================================================================================
    //                             INPUT DATA : SPOTTING
    // ================================================================================

    /**
    * @notice Submit new data to the protocol, in the stream, which will be added to the latest batch
                file_hashs_, URL_domains_ & item_counts_ must be of same length
    * @param file_hashs_ array of IPFS hashes, json format
    * @param URL_domains_ array of URL top domain per file (for statistics purpose)
    * @param item_counts_ array of size (in number of json items)
    * @param extra_ extra information (for indexing / archival purpose)
    */
    function SpotData(
        string[] memory file_hashs_,
        string[] calldata URL_domains_,
        uint64[] memory item_counts_,
        string memory extra_
    ) public
    whenNotPaused()
    returns(uint256 Dataid_) {
        require(IParametersManager(address(0)) != Parameters, "Parameters Manager must be set.");
        // ---- Spot Flow Management ---------------------------------------
        require(Parameters.get_SPOT_TOGGLE_ENABLED(), "Spotting is not currently enabled by Owner");
        require(file_hashs_.length == URL_domains_.length, "input arrays must be of same length (1)");
        require(file_hashs_.length == item_counts_.length, "input arrays must be of same length (2)");
        // -- global flow checking
        updateGlobalSpotFlow(); // first update the Global SpotFlow Management System
        require(
            getGlobalPeriodSpotCount() < Parameters.get_SPOT_GLOBAL_MAX_SPOT_PER_PERIOD(),
            "Global limit: exceeded max data per hour, retry later."
        );
        //_numTokens The number of tokens to be committed towards the target SpottedData
        uint256 _numTokens = Parameters.get_SPOT_MIN_STAKE();
        address _selectedAddress = SelectAddressForUser(msg.sender, _numTokens);
        // -- woker flow checking
        updateUserSpotFlow(_selectedAddress); // first update the User SpotFlow Management System
        // -----------------------------------------------------------------

        uint128 _batch_counter = LastBatchCounter;

        if (
            getUserPeriodSpotCount(_selectedAddress) < Parameters.get_SPOT_MAX_SPOT_PER_USER_PER_PERIOD() &&
            getGlobalPeriodSpotCount() < Parameters.get_SPOT_GLOBAL_MAX_SPOT_PER_PERIOD()
        ) {
            if (STAKING_REQUIREMENT_TOGGLE_ENABLED) {
                // ---  Master/SubWorker Stake Management
                // if tx sender has a master, then interact with his master's stake, or himself
                if (SystemStakedTokenBalance[_selectedAddress] < _numTokens) {
                    uint256 remainder = _numTokens - SystemStakedTokenBalance[_selectedAddress];
                    requestAllocatedStake(remainder, _selectedAddress);
                }
            }

            // -----------------------------------------------------------------
            // ---- Spot Batch Processing --------------------------------------
            for (uint64 i = 0; i < file_hashs_.length; i++) {
                string memory file_hash = file_hashs_[i];
                string memory URL_domain_ = URL_domains_[i];
                uint64 item_count_ = item_counts_[i];

                SpotsMapping[_ModS(DataNonce)] = SpottedData({
                    ipfs_hash: file_hash,
                    author: msg.sender,
                    timestamp: uint64(block.timestamp),
                    item_count: item_count_,
                    URL_domain: URL_domain_,
                    extra: extra_,
                    status: DataStatus.TBD
                });

                // UPDATE STREAMING DATA BATCH STRUCTURE
                BatchMetadata storage current_data_batch = DataBatch[_ModB(_batch_counter)];
                if (current_data_batch.counter < Parameters.get_SPOT_DATA_BATCH_SIZE()) {
                    current_data_batch.counter += 1;
                }
                if (current_data_batch.counter >= Parameters.get_SPOT_DATA_BATCH_SIZE()) {
                    // batch is complete trigger new work round, new batch
                    current_data_batch.complete = true;
                    current_data_batch.checked = false;
                    LastBatchCounter += 1;
                    delete DataBatch[_ModB(LastBatchCounter)];
                    // we indicate that the first spot of the new batch, is the one we just built
                    DataBatch[_ModB(_batch_counter)].start_idx = DataNonce;
                }

                // Global state update - spot flow management: increase global sliding counter & user counter
                DataNonce = DataNonce + 1;
                GlobalSpotFlowManager[GlobalSpotFlowManager.length - 1].counter += 1;
                TimeframeCounter[NB_TIMEFRAMES] storage UserSpotFlowManager = WorkersSpotFlowManager[
                    _selectedAddress];
                UserSpotFlowManager[UserSpotFlowManager.length - 1].counter += 1;

                if (InstantSpotRewards) {
                    address spot_author_ = msg.sender;
                    IAddressManager _AddressManager = IAddressManager(Parameters.getAddressManager());
                    IRepManager _RepManager = IRepManager(Parameters.getRepManager());
                    IRewardManager _RewardManager = IRewardManager(Parameters.getRewardManager());
                    address spot_author_master_ = _AddressManager.FetchHighestMaster(spot_author_);
                    uint256 rewardAmount = (Parameters.get_SPOT_MIN_REWARD_SpotData() * 100) /
                        InstantSpotRewardsDivider;
                    uint256 repAmount = (Parameters.get_SPOT_MIN_REP_SpotData() * 100) / InstantSpotRewardsDivider;
                    require(
                        _RepManager.mintReputationForWork(repAmount, spot_author_master_, ""),
                        "could not reward REP in ValidateDataBatch, 2.a"
                    );
                    require(
                        _RewardManager.ProxyAddReward(rewardAmount, spot_author_master_),
                        "could not reward token in ValidateDataBatch, 2.b"
                    );
                }

                // ---- Emit event
                emit _SpotSubmitted(DataNonce, file_hash, URL_domain_, _selectedAddress);
            }
            // -----------------------------------------------------------------
        }
        WorkerState storage worker_state = WorkersState[msg.sender];
        if (!worker_state.isWorkerSeen) {
            AllWorkersList.push(msg.sender);
            worker_state.isWorkerSeen = true;
        }
        worker_state.last_interaction_date = uint64(block.timestamp);

        _retrieveSFuel();
        AllTxsCounter += 1;
        return DataNonce;
    }


    // ================================================================================
    //                              STAKING & TOKEN INTERFACE
    // ================================================================================

    /**
     * @notice Loads _numTokens ERC20 tokens into the voting contract for one-to-one voting rights
     * @dev Assumes that msg.sender has approved voting contract to spend on their behalf
     * @param _numTokens The number of votingTokens desired in exchange for ERC20 tokens
     * @param user_ The user address
     */
    function requestAllocatedStake(uint256 _numTokens, address user_) internal {
        require(Parameters.getStakeManager() != address(0), "StakeManager is null in Parameters");
        IStakeManager _StakeManager = IStakeManager(Parameters.getStakeManager());
        require(
            _StakeManager.ProxyStakeAllocate(_numTokens, user_),
            "Could not request enough allocated stake, requestAllocatedStake"
        );
        if (SystemStakedTokenBalance[user_] == 0) {
            //----- Track Storage usage -----
            BytesUsed += BYTES_256; //boolean + vote + hash
            //----- Track Storage usage -----
        }

        SystemStakedTokenBalance[user_] += _numTokens;
        emit _StakeAllocated(_numTokens, user_);
    }

    /**
     * @notice Withdraw _numTokens ERC20 tokens from the voting contract, revoking these voting rights
     * @param _numTokens The number of ERC20 tokens desired in exchange for voting rights
     */
    function withdrawVotingRights(uint256 _numTokens) public {
        require(IParametersManager(address(0)) != Parameters, "Parameters Manager must be set.");
        address _selectedAddress = SelectAddressForUser(msg.sender, _numTokens);
        require(_selectedAddress != address(0), "Error: _selectedAddress is null during withdrawVotingRights");
        uint256 availableTokens = SystemStakedTokenBalance[_selectedAddress] - getLockedTokens(_selectedAddress);
        require(availableTokens >= _numTokens, "availableTokens should be >= _numTokens");

        IStakeManager _StakeManager = IStakeManager(Parameters.getStakeManager());
        SystemStakedTokenBalance[_selectedAddress] -= _numTokens;
        require(
            _StakeManager.ProxyStakeDeallocate(_numTokens, _selectedAddress),
            "Could not withdrawVotingRights through ProxyStakeDeallocate"
        );
        _retrieveSFuel();
        emit _VotingRightsWithdrawn(_numTokens, _selectedAddress);
    }

    /**
     * @notice get BytesUsed (storage space), monitored by the contract
     *         can be approximative
     */
    function getBytesUsed() public view returns(uint256 storage_size) {
        return BytesUsed;
    }
    /**
     * @notice get Locked Token for the current Contract (WorkSystem)
     * @param user_ The user address
     */
    function getSystemTokenBalance(address user_) public view returns(uint256 tokens) {
        return (uint256(SystemStakedTokenBalance[user_]));
    }


    /**
     * @dev Unlocks tokens locked in unrevealed spot-check-vote where SpottedData has ended
     * @param _DataBatchId Integer identifier associated with the target SpottedData
     */
    function rescueTokens(uint128 _DataBatchId) public {
        require(
            DataBatch[_ModB(_DataBatchId)].status == DataStatus.APPROVED,
            "given DataBatch should be APPROVED, and it is not"
        );
        require(dllMap[msg.sender].contains(_DataBatchId), "dllMap: does not cointain _DataBatchId for the msg sender");

        dllMap[msg.sender].remove(_DataBatchId);

        //----- Track Storage usage -----
        uint256 BytesUsedReduction = BYTES_128;
        if (BytesUsed >= BytesUsedReduction) {
            BytesUsed -= BytesUsedReduction;
        } else {
            BytesUsed = 0;
        }
        //----- Track Storage usage -----

        _retrieveSFuel();
        emit _TokensRescued(_DataBatchId, msg.sender);
    }

    /**
     * @dev Unlocks tokens locked in unrevealed spot-check-votes where Datas have ended
     * @param _DataBatchIDs Array of integer identifiers associated with the target Datas
     */
    function rescueTokensInMultipleDatas(uint128[] memory _DataBatchIDs) public {
        // loop through arrays, rescuing tokens from all
        for (uint256 i = 0; i < _DataBatchIDs.length; i++) {
            rescueTokens(_DataBatchIDs[i]);
        }
    }

    // ================================================================================
    //                              GETTERS - DATA
    // ================================================================================

    /**
     * @notice get all item counts for all batches between batch indices A and B (a < B)
     * @param _DataBatchId_a ID of the starting batch
     * @param _DataBatchId_b ID of the ending batch (included)
     */
    function getBatchCountForBatch(uint128 _DataBatchId_a, uint128 _DataBatchId_b)
    public
    view
    returns(uint128 AverageURLCount, uint128[] memory batchCounts) {
        require(_DataBatchId_a > 0 && _DataBatchId_a < _DataBatchId_b, "Input boundaries are invalid");
        uint128 _total_batchs_count = 0;
        uint128 _batch_amount = _DataBatchId_b - _DataBatchId_a + 1;

        uint128[] memory _batch_counts_list = new uint128[](_batch_amount);

        for (uint128 i = 0; i < _batch_amount; i++) {
            BatchMetadata memory batch_ = DataBatch[_ModB(i + _DataBatchId_a)];
            _total_batchs_count += batch_.item_count;
            _batch_counts_list[i] = batch_.item_count;
        }

        uint128 _average_batch_count = _total_batchs_count / _batch_amount;

        return (_average_batch_count, _batch_counts_list);
    }

    /**
     * @notice get top domain URL for a given batch
     * @param _DataBatchId ID of the batch
     */
    function getDomainsForBatch(uint128 _DataBatchId) public view returns(string[] memory) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");
        BatchMetadata memory batch_ = DataBatch[_ModB(_DataBatchId)];
        uint128 batch_size = batch_.counter;

        string[] memory ipfs_hash_list = new string[](batch_size);

        for (uint128 i = 0; i < batch_size; i++) {
            uint128 k = batch_.start_idx + i;
            string memory ipfs_hash_ = SpotsMapping[_ModS(k)].URL_domain;
            ipfs_hash_list[i] = ipfs_hash_;
        }

        return ipfs_hash_list;
    }




    // ----------------------------------------------------
    // ----------------------------------------------------
    //                     Data HELPERS
    // ----------------------------------------------------
    // ----------------------------------------------------

    /**
     * @dev Compares previous and next SpottedData's committed tokens for sorting purposes
     * @param _prevID Integer identifier associated with previous SpottedData in sorted order
     * @param _nextID Integer identifier associated with next SpottedData in sorted order
     * @param _voter Address of user to check DLL position for
     * @param _numTokens The number of tokens to be committed towards the SpottedData (used for sorting)
     * @return APPROVED Boolean indication of if the specified position maintains the sort
     */
    function validPosition(
        uint128 _prevID,
        uint128 _nextID,
        address _voter,
        uint256 _numTokens
    ) public view returns(bool APPROVED) {
        bool prevValid = (_numTokens >= getNumTokens(_voter, _prevID));
        // if next is zero node, _numTokens does not need to be greater
        bool nextValid = (_numTokens <= getNumTokens(_voter, _nextID) || _nextID == 0);
        return prevValid && nextValid;
    }

    /**
     * @notice Determines if proposal has passed
     * @dev Check if votesFor out of totalSpotChecks exceeds votesQuorum
     * @param _DataBatchId Integer identifier associated with target SpottedData
     */
    function isPassed(uint128 _DataBatchId) public view returns(bool passed) {
        BatchMetadata memory batch_ = DataBatch[_ModB(_DataBatchId)];
        return (100 * batch_.votesFor) > (Parameters.getVoteQuorum() * (batch_.votesFor + batch_.votesAgainst));
    }

    
    /**
     * @notice get Last Data Id
     * @return DataId
     */
    function getLastDataId() public view returns(uint256 DataId) {
        return DataNonce;
    }

    /**
     * @notice get Last Batch Id
     * @return LastBatchId
     */
    function getLastBatchId() public view returns(uint256 LastBatchId) {
        return LastBatchCounter;
    }

    /**
     * @notice get DataBatch By ID
     * @return batch as BatchMetadata struct
     */
    function getBatchByID(uint128 _DataBatchId) public view returns(BatchMetadata memory batch) {
        require(DataExists(_DataBatchId));
        return DataBatch[_ModB(_DataBatchId)];
    }


    /**
     * @notice get all IPFS hashes, input of the batch 
     * @param _DataBatchId ID of the batch
     */
    function getBatchIPFSFileByID(uint128 _DataBatchId) public view returns(string[] memory) {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");
        BatchMetadata memory batch_ = DataBatch[_ModB(_DataBatchId)];
        uint256 batch_size = batch_.counter;

        string[] memory ipfs_hash_list = new string[](batch_size);

        for (uint128 i = 0; i < batch_size; i++) {
            uint128 k = batch_.start_idx + i;
            string memory ipfs_hash_ = SpotsMapping[_ModS(k)].ipfs_hash;
            ipfs_hash_list[i] = ipfs_hash_;
        }

        return ipfs_hash_list;
    }

    /**
     * @notice get all IPFS hashes, input of batchs, between batch indices A and B (a < B)
     * @param _DataBatchId_a ID of the starting batch
     * @param _DataBatchId_b ID of the ending batch (included)
     */
    function getBatchsFilesByID(uint128 _DataBatchId_a, uint128 _DataBatchId_b)
    public
    view
    returns(string[] memory) {
        require(_DataBatchId_a > 0 && _DataBatchId_a < _DataBatchId_b, "Input boundaries are invalid");
        uint128 _ipfs_hash_count = 0;

        for (uint128 batchI = _DataBatchId_a; batchI < _DataBatchId_b + 1; batchI++) {
            BatchMetadata memory batch_ = DataBatch[_ModB(batchI)];
            _ipfs_hash_count += batch_.counter;
        }
        string[] memory ipfs_hash_list = new string[](_ipfs_hash_count);

        uint128 c = 0;
        for (uint128 batchI = _DataBatchId_a; batchI < _DataBatchId_b + 1; batchI++) {
            BatchMetadata memory batch_ = DataBatch[_ModB(batchI)];
            for (uint128 i = 0; i < batch_.counter; i++) {
                uint128 k = batch_.start_idx + i;
                string memory ipfs_hash_ = SpotsMapping[_ModS(k)].ipfs_hash;
                ipfs_hash_list[c] = ipfs_hash_;
                c += 1;
            }
        }

        return ipfs_hash_list;
    }

    /**
     * @dev Returns all worker addresses between index A_ and index B
     * @param A_ Address of user to check against
     * @param B_ Integer identifier associated with target SpottedData
     * @return workers array of workers of size (B_-A_+1)
     */
    function getAllWorkersBetweenIndex(uint256 A_, uint256 B_) public view returns(address[] memory workers) {
        require(B_ >= A_, " _B must be >= _A");
        require(B_ <= (AllWorkersList.length - 1), " B_ is out of bounds");
        uint256 _array_size = B_ - A_ + 1;
        address[] memory address_list = new address[](_array_size);
        for (uint256 i = 0; i < _array_size; i++) {
            address_list[i] = AllWorkersList[i + A_];
        }
        return address_list;
    }

    /**b
     * @notice get AllWorkersList length
     * @return length of the array
     */
    function getAllWorkersLength() public view returns(uint256 length) {
        return AllWorkersList.length;
    }

    /**
     * @notice get Data By ID
     * @return data as SpottedData struct
     */
    function getDataByID(uint128 _DataId) public view returns(SpottedData memory data) {
        return SpotsMapping[_ModS(_DataId)];
    }

    /**
     * @notice getCounter
     * @return Counter of all "accepted transactions"
     */
    function getTxCounter() public view returns(uint256 Counter) {
        return AllTxsCounter;
    }

    /**
     * @notice getCounter
     * @return Counter of the last Dataed a user started
     */
    function getItemCounter() public view returns(uint256 Counter) {
        return AllItemCounter;
    }

    /**
     * @dev Checks if a SpottedData exists
     * @param _DataBatchId The DataID whose existance is to be evaluated.
     * @return exists Boolean Indicates whether a SpottedData exists for the provided DataID
     */
    function DataExists(uint128 _DataBatchId) public view returns(bool exists) {
        return (DataBatch[_ModB(_DataBatchId)].complete);
    }


    /**
     * @dev Wrapper for getAttribute with attrName="numTokens"
     * @param _voter Address of user to check against
     * @param _DataBatchId Integer identifier associated with target SpottedData
     * @return numTokens Number of tokens committed to SpottedData in sorted SpottedData-linked-list
     */
    function getNumTokens(address _voter, uint128 _DataBatchId) public view returns(uint256 numTokens) {
        return getAttribute(attrUUID(_voter, _DataBatchId), "numTokens");
    }

    /**
     * @dev Gets top element of sorted SpottedData-linked-list
     * @param _voter Address of user to check against
     * @return DataID Integer identifier to SpottedData with maximum number of tokens committed to it
     */
    function getLastNode(address _voter) public view returns(uint128 DataID) {
        return dllMap[_voter].getPrev(0);
    }

    /**
     * @dev Gets the numTokens property of getLastNode
     * @param _voter Address of user to check against
     * @return numTokens Maximum number of tokens committed in SpottedData specified
     */
    function getLockedTokens(address _voter) public view returns(uint256 numTokens) {
        return getNumTokens(_voter, getLastNode(_voter));
    }

    /*
  * @dev Takes the last node in the user's DLL and iterates backwards through the list searching
  for a node with a value less than or equal to the provided _numTokens value. When such a node
  is found, if the provided _DataBatchId matches the found nodeID, this operation is an in-place
  update. In that case, return the previous node of the node being updated. Otherwise return the
  first node that was found with a value less than or equal to the provided _numTokens.
  * @param _voter The voter whose DLL will be searched
  * @param _numTokens The value for the numTokens attribute in the node to be inserted
  * @return the node which the propoded node should be inserted after
  */
    function getInsertPointForNumTokens(
        address _voter,
        uint256 _numTokens,
        uint128 _DataBatchId
    ) public view returns(uint256 prevNode) {
        // Get the last node in the list and the number of tokens in that node
        uint128 nodeID = getLastNode(_voter);
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
            // We did not find the insert point. Continue iterating backwards through th    e list
            nodeID = dllMap[_voter].getPrev(nodeID);
        }

        // The list is empty, or a smaller value than anything else in the list is being inserted
        return nodeID;
    }

    // ----------------
    // GENERAL HELPERS:
    // ----------------

    /**
     * @dev Checks if an expiration date has been reached
     * @param _terminationDate Integer timestamp of date to compare current timestamp with
     * @return expired Boolean indication of whether the terminationDate has passed
     */
    function isExpired(uint256 _terminationDate) public view returns(bool expired) {
        return (block.timestamp > _terminationDate);
    }

    /**
     * @dev Generates an identifier which associates a user and a SpottedData together
     * @param _DataBatchId Integer identifier associated with target SpottedData
     * @return UUID Hash which is deterministic from user_ and _DataBatchId
     */
    function attrUUID(address user_, uint128 _DataBatchId) public pure returns(bytes32 UUID) {
        return keccak256(abi.encodePacked(user_, _DataBatchId));
    }
}
