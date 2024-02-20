// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title WorkSystem Quality v1.3.4a
 * @author Mathias Dail - CTO @ Exorde Labs 2022
 */

import "@openzeppelin/contracts/utils/Context.sol";
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
import "./RandomSubsets.sol";

/**
 * @title WorkSystem Quality v1.3.4a
 * @author Mathias Dail - CTO @ Exorde Labs
 */
contract DataQuality is Ownable, Pausable, RandomSubsets, IDataQuality {
    // ============ EVENTS ============
    event _QualitySubmitted(
        uint256 indexed DataID,
        string file_hash,
        address indexed sender
    );
    event _QualityCheckCommitted(
        uint256 indexed DataID,
        address indexed voter
    );
    event _QualityCheckRevealed(
        uint256 indexed DataID,
        address indexed voter
    );
    event _RelevanceCheckCommitted(
        uint256 indexed DataID,
        address indexed voter
    );
    event _RelevanceCheckRevealed(
        uint256 indexed DataID,
        address indexed voter
    );
    event _BatchQualityValidated(uint256 indexed DataID, DataItemVote statuses);
    event _WorkAllocated(uint256 indexed batchID, address worker);
    event _WorkerRegistered(address indexed worker, uint256 timestamp);
    event _WorkerUnregistered(address indexed worker, uint256 timestamp);
    event _StakeAllocated(uint256 numTokens, address indexed voter);
    event _VotingRightsWithdrawn(uint256 numTokens, address indexed voter);
    event _TokensRescued(uint256 indexed DataID, address indexed voter);
    event _DataBatchDeleted(uint256 indexed batchID);
    event ParametersUpdated(address parameters);

    event BytesFailure(bytes bytesFailure);

    // ================================================================================
    //                             Constructor
    // ================================================================================
    constructor(address Parameters_) Ownable(msg.sender) {
        require(Parameters_ != address(0), "Parameters_ must be non zero");
        Parameters = IParametersManager(Parameters_);
        emit ParametersUpdated(Parameters_);
    }

    // ====================================
    //        GLOBAL STATE VARIABLES
    // ====================================


    struct DataItemVote {
        // Dynamic arrays of uint8
        uint8[] indices;
        uint8[] statuses;
        // Additional attributes - replace these with your actual attribute types and names
        bytes32 extra;
        bytes32 _id;
    }

    struct Tuple {
        uint8 index;
        uint8 status;
    }

    // ------ Quality input flow management
    uint64 public LastAllocationTime = 0;
    uint16 constant NB_TIMEFRAMES = 15;
    uint16 constant MAX_MASTER_DEPTH = 3;
    TimeframeCounter[NB_TIMEFRAMES] public ItemFlowManager;

    // ------ User Submissions & Voting related structure
    mapping(uint128 => mapping(address => VoteSubmission))
        public UserQualityVoteSubmission;
    mapping(uint128 => mapping(address => VoteSubmission))
        public UserRelevanceVoteSubmission;
    // 1. Quality structures
    mapping(uint128 => mapping(address => bytes32))
        public QualityHashes;
    //  BatchID => (UserAddress => lists (index, value))
    mapping(uint128 => mapping(address => DataItemVote))
        public QualitySubmissions;

    // 2. Relevance Structures
    mapping(uint128 => mapping(address => bytes32))
        public UserEncryptedBaseCounts;
    mapping(uint128 => mapping(address => bytes32))
        public UserEncryptedDuplicates;
    mapping(uint128 => mapping(address => bytes32))
        public UserEncryptedBountiesCounts;
        
    //  BatchID => (UserAddress => lists (index, value))
    mapping(uint128 => mapping(address => DataItemVote))
        public UserClearCounts;
    mapping(uint128 => mapping(address => DataItemVote))
        public UserClearDuplicatesIndices;
    mapping(uint128 => mapping(address => DataItemVote))
        public UserClearBountiesCounts;

    // ------ Backend Data Stores
    mapping(uint128 => QualityData) public InputFilesMap; // maps DataID to QualityData struct
    mapping(uint128 => BatchMetadata) public ProcessedBatch; 
    mapping(uint128 => ProcessMetadata) public ProcessBatchInfo; 
    // structure to store the subsets for each batch
    mapping(uint128 => uint128[][]) public RandomQualitySubsets;

    // ------ Worker & Stake related structure
    mapping(address => WorkerState) public WorkersState;
    mapping(address => uint256) public SystemStakedTokenBalance; // maps user's address to voteToken balance

    // ------ Worker management structures
    mapping(address => WorkerStatus) public WorkersStatus;
    mapping(uint128 => address[]) public WorkersPerQualityBatch;
    mapping(uint128 => address[]) public WorkersPerRelevanceBatch;
    mapping(uint128 => uint16) public QualityBatchCommitedVoteCount;
    mapping(uint128 => uint16) public QualityBatchRevealedVoteCount;
    mapping(uint128 => uint16) public RelevanceBatchCommitedVoteCount;
    mapping(uint128 => uint16) public RelevanceBatchRevealedVoteCount;

    uint16 constant MIN_REGISTRATION_DURATION = 120; // in seconds

    uint32 private REMOVED_WORKER_INDEX_VALUE = 2**32 - 1;

    uint8 constant NB_UNIQUE_QUALITY_STATUSES = 4;


    address[] public availableWorkers;
    address[] public busyWorkers;
    address[] public toUnregisterWorkers;
    address[] public AllWorkersList;

    // ------ Processes counters
    uint128 public DataNonce = 0;
    // -- Batches Counters
    uint128 public BatchDeletionCursor = 1;
    uint128 public LastBatchCounter = 1;
    uint128 public BatchCheckingCursor = 1;
    uint128 public AllocatedBatchCursor = 1;

    // ------ Statistics related counters
    uint128 public AcceptedBatchsCounter = 0;
    uint128 public RejectedBatchsCounter = 0;
    uint128 public NotCommitedCounter = 0;
    uint128 public NotRevealedCounter = 0;
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
    uint128 public MAX_INDEX_RANGE_ITEMS = 10000 * 30;

    // ------ Vote related
    uint16 constant APPROVAL_VOTE_MAPPING_ = 1;
    uint16 immutable MAX_WORKER_ALLOCATED_PER_BATCH = 30;

    // ------------ Rewards & Work allocation related
    bool public STAKING_REQUIREMENT_TOGGLE_ENABLED = false;
    bool public InstantRevealRewards = true;
    uint16 public InstantRevealRewardsDivider = 1;
    uint16 public MaxPendingDataBatchCount = 250;
    // Data random integrity check parameters
    uint128 public _Quality_subset_count = 2;
    uint128 public _Quality_coverage = 5;
    uint16 public QUALITY_FILE_SIZE_MIN = 1000;
    uint256 public MAX_ONGOING_JOBS = 500;
    uint256 public NB_BATCH_TO_TRIGGER_GARBAGE_COLLECTION = 1000;
    uint256 private MIN_OFFSET_DELETION_CURSOR = 50;

    uint256 MAJORITY_THRESHOLD_PERCENT = 50;

    /**
    * @dev Enum to specify the type of task for work allocation.
    */
    enum TaskType { Quality, Relevance }

    // ---------------------

    // ------ Addresses & Interfaces
    IParametersManager public Parameters;

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
     * @notice Enable or disable instant rewards when Revealing (Testnet)
     * @param state_ boolean
     * @param divider_ base rewards divider
     */
    function updateInstantRevealRewards(bool state_, uint16 divider_)
        public
        onlyOwner
    {
        InstantRevealRewards = state_;
        InstantRevealRewardsDivider = divider_;
    }

    /**
     * @notice update MaxPendingDataBatchCount, limiting the queue of data to validate
     * @param MaxPendingDataBatchCount_ max queue size
     */
    function updateMaxPendingDataBatch(uint16 MaxPendingDataBatchCount_)
        public
        onlyOwner
    {
        MaxPendingDataBatchCount = MaxPendingDataBatchCount_;
    }

    /**
     * @notice update MAX_ONGOING_JOBS, limiting the number of parallel jobs in the system
     * @param MAX_ONGOING_JOBS_ max jobs in processing at any time
     */
    function updateMaxOngoingWorks(uint16 MAX_ONGOING_JOBS_) public onlyOwner {
        MAX_ONGOING_JOBS = MAX_ONGOING_JOBS_;
    }

    /**
     * @notice update MaxPendingDataBatchCount, limiting the queue of data to validate
     * @param NewGarbageCollectTreshold_ new threshold for deletion of batchs data
     */
    function updateGarbageCollectionThreshold(
        uint256 NewGarbageCollectTreshold_
    ) public onlyOwner {
        require(
            NewGarbageCollectTreshold_ > 100,
            "NewGarbageCollectTreshold_ must be > 100"
        );
        NB_BATCH_TO_TRIGGER_GARBAGE_COLLECTION = NewGarbageCollectTreshold_;
    }

    // ================================================================================
    //                              sFuel (eth) Auto Top Up system
    // ================================================================================

    /**
     * @notice Refill the msg.sender with sFuel. Skale gasless "gas station network" equivalent
     */
    function _retrieveSFuel() internal {
        require(
            IParametersManager(address(0)) != Parameters,
            "Parameters Manager must be set."
        );
        address sFuelAddress;
        sFuelAddress = Parameters.getsFuelSystem();
        require(sFuelAddress != address(0), "sFuel: null Address Not Valid");
        (bool success1, ) = sFuelAddress.call(
            abi.encodeWithSignature(
                "retrieveSFuel(address)",
                payable(msg.sender)
            )
        );
        (bool success2, ) = sFuelAddress.call(
            abi.encodeWithSignature(
                "retrieveSFuel(address payable)",
                payable(msg.sender)
            )
        );
        require(
            (success1 || success2),
            "receiver rejected _retrieveSFuel call"
        );
    }

    // ================================================================================
    //                         WORKER REGISTRATION & LOBBY MANAGEMENT
    // ================================================================================

    /** @notice returns BatchId modulo MAX_INDEX_RANGE_BATCHS
     */
    function _ModB(uint128 BatchId) private view returns (uint128) {
        return BatchId % MAX_INDEX_RANGE_BATCHS;
    }

    /** @notice returns SpotId modulo MAX_INDEX_RANGE_ITEMS
     */
    function _ModS(uint128 SpotId) private view returns (uint128) {
        return SpotId % MAX_INDEX_RANGE_ITEMS;
    }

    /**
     * @notice Checks if Worker is Available
     * @param _worker worker address
     */
    function isInAvailableWorkers(address _worker) public view returns (bool) {
        return WorkersStatus[_worker].isActiveWorker;
    }

    /**
     * @notice Checks if Worker is Busy
     * @param _worker worker address
     */
    function isInBusyWorkers(address _worker) public view returns (bool) {
        return WorkersStatus[_worker].isBusyWorker;
    }

    /**
     * @notice Checks if Worker in the "to log off" list
     */
    function IsInLogoffList(address _worker) public view returns (bool) {
        return WorkersStatus[_worker].isToUnregisterWorker;
    }

    /**
     * @notice Pop _worker from the Available workers
     */
    function PopFromAvailableWorkers(address _worker) internal {
        WorkerStatus storage workerStatus = WorkersStatus[_worker];
        if (workerStatus.isActiveWorker) {
            uint32 PreviousIndex = workerStatus.availableWorkersIndex;
            address SwappedWorkerAtIndex = availableWorkers[
                availableWorkers.length - 1
            ];

            // Update Worker State
            workerStatus.isActiveWorker = false;
            workerStatus.availableWorkersIndex = REMOVED_WORKER_INDEX_VALUE; // reset available worker index

            if (availableWorkers.length >= 2) {
                availableWorkers[PreviousIndex] = SwappedWorkerAtIndex; // swap last worker to this new position
                // Update moved item Index
                WorkersStatus[SwappedWorkerAtIndex]
                    .availableWorkersIndex = PreviousIndex;
            }

            availableWorkers.pop(); // pop last worker

            //----- Track Storage usage -----
            uint256 BytesUsedReduction = BYTES_256;
            if (BytesUsed >= BytesUsedReduction) {
                BytesUsed -= BytesUsedReduction;
            } else {
                BytesUsed = 0;
            }
            //----- Track Storage usage -----
        }
    }

    /**
     * @notice Pop worker from the Busy workers
     */
    function PopFromBusyWorkers(address _worker) internal {
        WorkerStatus storage workerStatus = WorkersStatus[_worker];
        if (workerStatus.isBusyWorker) {
            uint32 PreviousIndex = workerStatus.busyWorkersIndex;
            address SwappedWorkerAtIndex = busyWorkers[busyWorkers.length - 1];

            // Update Worker State
            workerStatus.isBusyWorker = false;
            workerStatus.busyWorkersIndex = REMOVED_WORKER_INDEX_VALUE; // reset available worker index

            if (busyWorkers.length >= 2) {
                busyWorkers[PreviousIndex] = SwappedWorkerAtIndex; // swap last worker to this new position
                // Update moved item Index
                WorkersStatus[SwappedWorkerAtIndex]
                    .busyWorkersIndex = PreviousIndex;
            }

            busyWorkers.pop(); // pop last worker

            //----- Track Storage usage -----
            uint256 BytesUsedReduction = BYTES_256;
            if (BytesUsed >= BytesUsedReduction) {
                BytesUsed -= BytesUsedReduction;
            } else {
                BytesUsed = 0;
            }
            //----- Track Storage usage -----
        }
    }

    function PopFromLogoffList(address _worker) internal {
        WorkerStatus storage workerStatus = WorkersStatus[_worker];
        if (workerStatus.isToUnregisterWorker) {
            uint32 PreviousIndex = workerStatus.toUnregisterWorkersIndex;
            address SwappedWorkerAtIndex = toUnregisterWorkers[
                toUnregisterWorkers.length - 1
            ];

            // Update Worker State
            workerStatus.isToUnregisterWorker = false;
            workerStatus.toUnregisterWorkersIndex = REMOVED_WORKER_INDEX_VALUE; // reset available worker index

            if (busyWorkers.length >= 2) {
                toUnregisterWorkers[PreviousIndex] = SwappedWorkerAtIndex; // swap last worker to this new position
                // Update moved item Index
                WorkersStatus[SwappedWorkerAtIndex]
                    .toUnregisterWorkersIndex = PreviousIndex;
            }

            toUnregisterWorkers.pop(); // pop last worker

            //----- Track Storage usage -----
            uint256 BytesUsedReduction = BYTES_256;
            if (BytesUsed >= BytesUsedReduction) {
                BytesUsed -= BytesUsedReduction;
            } else {
                BytesUsed = 0;
            }
            //----- Track Storage usage -----
        }
    }

    function PushInAvailableWorkers(address _worker) internal {
        require(
            _worker != address(0),
            "Error: Can't push the null address in available workers"
        );
        if (!isInAvailableWorkers(_worker)) {
            availableWorkers.push(_worker);

            //----- Track Storage usage -----
            BytesUsed += BYTES_256; //address added
            //----- Track Storage usage -----

            // Update Worker State
            WorkersStatus[_worker].isActiveWorker = true;
            WorkersStatus[_worker].availableWorkersIndex = uint32(
                availableWorkers.length - 1
            );
            // we can cast safely because availableWorkers.length << 2**32
        }
    }

    function PushInBusyWorkers(address _worker) internal {
        require(
            _worker != address(0),
            "Error: Can't push the null address in busy workers"
        );
        if (!isInBusyWorkers(_worker)) {
            busyWorkers.push(_worker);

            //----- Track Storage usage -----
            BytesUsed += BYTES_256; //address added
            //----- Track Storage usage -----

            // Update Worker State
            WorkersStatus[_worker].isBusyWorker = true;
            WorkersStatus[_worker].busyWorkersIndex = uint32(
                busyWorkers.length - 1
            );
        }
    }

    /**
     * @notice Check if worker allocated to batch _DataBatchId
                There is no loop break here, because the number of 
                allocated workers per batch is always low (< 50). 
                This loop can be considered O(1).
     * @param _DataBatchId _DataBatchId
     * @param _worker address
     * @return bool if worker allocated to batch
     */
    function isWorkerAllocatedToBatch(uint128 _DataBatchId, address _worker, TaskType _task)
        public
        view
        returns (bool)
    {
        bool found = false;
        if (_task == TaskType.Quality) {
            address[] memory allocated_workers = WorkersPerQualityBatch[
                _ModB(_DataBatchId)
            ];
            for (uint256 i = 0; i < allocated_workers.length; i++) {
                if (allocated_workers[i] == _worker) {
                    found = true;
                    break;
                }
            }
        } else {
            address[] memory allocated_workers = WorkersPerRelevanceBatch[
                _ModB(_DataBatchId)
            ];
            for (uint256 i = 0; i < allocated_workers.length; i++) {
                if (allocated_workers[i] == _worker) {
                    found = true;
                    break;
                }
            }
        }
        return found;
    }

    /* 
        Select Address for a worker address, between itself and a potential Master Address    
    Crawl up the tree of master (depth can be max 3: worker -> master-worker -> main address)
    */
    function SelectAddressForUser(
        address _worker,
        uint256 _TokensAmountToAllocate
    ) public view returns (address) {
        require(
            IParametersManager(address(0)) != Parameters,
            "Parameters Manager must be set."
        );
        require(
            Parameters.getAddressManager() != address(0),
            "AddressManager is null in Parameters"
        );
        require(
            Parameters.getStakeManager() != address(0),
            "StakeManager is null in Parameters"
        );
        IStakeManager _StakeManager = IStakeManager(
            Parameters.getStakeManager()
        );
        IAddressManager _AddressManager = IAddressManager(
            Parameters.getAddressManager()
        );

        address _SelectedAddress = _worker;
        address _CurrentAddress = _worker;

        for (uint256 i = 0; i < MAX_MASTER_DEPTH; i++) {
            // check if _CurrentAddress has enough available stake
            uint256 _CurrentAvailableStake = _StakeManager
                .AvailableStakedAmountOf(_CurrentAddress);

            // Case 1 : the _CurrentAddress has enough staked in the system already, then good.
            if (
                SystemStakedTokenBalance[_CurrentAddress] >=
                _TokensAmountToAllocate
            ) {
                // Found enough Staked in the system already, return this address
                _SelectedAddress = _CurrentAddress;
                break;
            }
            // Case 2 : the _CurrentAddress has partially enough staked in the system already
            else if (
                SystemStakedTokenBalance[_CurrentAddress] <=
                _TokensAmountToAllocate &&
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

    function IsAddressKicked(address user_) public view returns (bool status) {
        bool status_ = false;
        WorkerState memory worker_state = WorkersState[user_];
        if (
            (worker_state.succeeding_novote_count >=
                Parameters.get_MAX_SUCCEEDING_NOVOTES() &&
                ((block.timestamp - worker_state.registration_date) <
                    Parameters.get_NOVOTE_REGISTRATION_WAIT_DURATION()))
        ) {
            status_ = true;
        }
        return status_;
    }

    function AmIKicked() public view returns (bool status) {
        return IsAddressKicked(msg.sender);
    }

    function processLogoffRequests(uint256 n_iteration) internal {
        uint256 iteration_count = Math.min(
            n_iteration,
            toUnregisterWorkers.length
        );
        for (uint256 i = 0; i < iteration_count; i++) {
            address worker_addr_ = toUnregisterWorkers[i];
            WorkerState storage worker_state = WorkersState[worker_addr_];
            if (worker_state.currently_working == false) {
                /////////////////////////////////
                worker_state.registered = false;
                worker_state.unregistration_request = false;
                PopFromAvailableWorkers(worker_addr_);
                PopFromBusyWorkers(worker_addr_);
                WorkersStatus[worker_addr_].isToUnregisterWorker = false;
                emit _WorkerUnregistered(worker_addr_, block.timestamp);

                //----- Track Storage usage -----
                // boolean reset
                uint256 BytesUsedReduction = BYTES_8 * 3;
                if (BytesUsed >= BytesUsedReduction) {
                    BytesUsed -= BytesUsedReduction;
                } else {
                    BytesUsed = 0;
                }
                //----- Track Storage usage -----
            }
        }
        if (toUnregisterWorkers.length == 0) {
            delete toUnregisterWorkers;
        }
    }

    /* Register worker (online) */
    function RegisterWorker() public {
        WorkerState storage worker_state = WorkersState[msg.sender];
        require(
            IParametersManager(address(0)) != Parameters,
            "Parameters Manager must be set."
        );

        // Check if worker can register
        require(canWorkerRegister(worker_state), "Worker cannot register");

        // Handle staking requirements
        handleStakingRequirement(msg.sender);

        // Add worker to availableWorkers list
        PushInAvailableWorkers(msg.sender);

        // Update worker state on registration
        updateWorkerStateOnRegistration(msg.sender, worker_state);

        //----- Track Storage usage -----
        BytesUsed += BYTES_256 * 2; // WorkerState is packed in 2 slots
        //----- Track Storage usage -----

        AllTxsCounter += 1;
        _retrieveSFuel();
        emit _WorkerRegistered(msg.sender, block.timestamp);
    }

    function UnregisterWorker() public {
        WorkerState storage worker_state = WorkersState[msg.sender];

        // Check if worker can unregister
        require(canWorkerUnregister(worker_state), "Worker cannot unregister");

        if (shouldRequestUnregistration(worker_state)) {
            // Request unregistration
            requestUnregistration(msg.sender, worker_state);
        } else {
            // Update worker state on unregistration
            unregisterWorkerAndUpdateState(msg.sender, worker_state);
            emit _WorkerUnregistered(msg.sender, block.timestamp);
        }

        AllTxsCounter += 1;
        _retrieveSFuel();
    }

    // Check if the worker can unregister
    function canWorkerUnregister(WorkerState storage worker_state)
        internal
        view
        returns (bool)
    {
        require(
            worker_state.registered,
            "Worker is not registered so can't unregister"
        );
        require(
            worker_state.registration_date <
                block.timestamp + MIN_REGISTRATION_DURATION,
            "Worker must wait some time to unregister"
        );
        return true;
    }

    // Check if the worker should request unregistration
    function shouldRequestUnregistration(WorkerState storage worker_state)
        internal
        view
        returns (bool)
    {
        return
            worker_state.currently_working == true &&
            !worker_state.unregistration_request &&
            !IsInLogoffList(msg.sender);
    }

    function requestUnregistration(
        address worker,
        WorkerState storage worker_state
    ) internal {
        worker_state.unregistration_request = true;
        toUnregisterWorkers.push(worker);
        BytesUsed += BYTES_256;
        WorkersStatus[worker].isToUnregisterWorker = true;
    }

    function unregisterWorkerAndUpdateState(
        address worker,
        WorkerState storage worker_state
    ) internal {
        PopFromAvailableWorkers(worker);
        PopFromBusyWorkers(worker);
        PopFromLogoffList(worker);
        worker_state.last_interaction_date = uint64(block.timestamp);
        WorkersStatus[worker].isToUnregisterWorker = false;
        worker_state.registered = false;
    }

    // Check if the worker can register
    function canWorkerRegister(WorkerState storage worker_state)
        internal
        view
        returns (bool)
    {
        require(
            (availableWorkers.length + busyWorkers.length) <
                Parameters.getMaxTotalWorkers(),
            "Maximum registered workers already"
        );
        // Check if worker not at all in any ongoing process
        require(
            !isInAvailableWorkers(msg.sender) && !isInBusyWorkers(msg.sender),
            "Worker is already registered (2)"
        );
        // Check if worker not temporarily kicked
        require(
            !(worker_state.succeeding_novote_count >=
                Parameters.get_MAX_SUCCEEDING_NOVOTES() &&
                (block.timestamp - worker_state.registration_date) <
                Parameters.get_NOVOTE_REGISTRATION_WAIT_DURATION()),
            "Address kicked temporarily from participation"
        );
        return !worker_state.registered;
    }

    // Handle staking requirements for the worker
    // -> Master/SubWorker Stake Management
    // -> _numTokens The number of tokens to be allocated
    function handleStakingRequirement(address worker) internal {
        if (STAKING_REQUIREMENT_TOGGLE_ENABLED) {
            uint256 _numTokens = Parameters.get_QUALITY_MIN_STAKE();
            address _selectedAddress = SelectAddressForUser(worker, _numTokens);

            // if tx sender has a master, then interact with his master's stake, or himself
            if (SystemStakedTokenBalance[_selectedAddress] < _numTokens) {
                uint256 remainder = _numTokens -
                    SystemStakedTokenBalance[_selectedAddress];
                requestAllocatedStake(remainder, _selectedAddress);
            }
        }
    }

    function updateWorkerStateOnRegistration(
        address worker,
        WorkerState storage worker_state
    ) internal {
        // Update worker state on successful registration
        if (!worker_state.isWorkerSeen) {
            AllWorkersList.push(worker);
            worker_state.isWorkerSeen = true;
            BytesUsed += BYTES_256 + BYTES_8 + BYTES_256 * NB_TIMEFRAMES;
        }
        worker_state.registered = true;
        worker_state.unregistration_request = false;
        worker_state.registration_date = uint64(block.timestamp);
        worker_state.succeeding_novote_count = 0;
    }

    // Update worker state on unregistration
    function updateWorkerStateOnUnregistration(
        address worker,
        WorkerState storage worker_state
    ) internal {
        worker_state.last_interaction_date = uint64(block.timestamp);
        WorkersStatus[worker].isToUnregisterWorker = false;
        worker_state.registered = false;
    }

    function isWorkerRegistered(address worker) internal view returns (bool) {
        WorkerState storage worker_state = WorkersState[worker];
        return worker_state.registered;
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
        if (
            (BatchDeletionCursor <
                (BatchCheckingCursor - MIN_OFFSET_DELETION_CURSOR))
        ) {
            // Here the amount of iterations is capped by get_MAX_UPDATE_ITERATIONS
            for (uint128 i = 0; i < iteration_count; i++) {
                _deletion_index = BatchDeletionCursor;
                // First Delete Atomic Data composing the Batch, from start to end indices
                uint128 start_batch_idx = ProcessedBatch[_ModB(_deletion_index)]
                    .start_idx;
                uint128 end_batch_idx = ProcessedBatch[_ModB(_deletion_index)]
                    .start_idx + ProcessedBatch[_ModB(_deletion_index)].counter;
                for (uint128 l = start_batch_idx; l < end_batch_idx; l++) {
                    delete InputFilesMap[_ModS(l)]; // delete InputFilesMap at index l
                }
                // delete the batch
                delete ProcessedBatch[_ModB(_deletion_index)];
                // delete the BatchCommitedVoteCount && BatchRevealedVoteCount
                delete QualityBatchCommitedVoteCount[_ModB(_deletion_index)];
                delete QualityBatchRevealedVoteCount[_ModB(_deletion_index)];
                delete RelevanceBatchCommitedVoteCount[_ModB(_deletion_index)];
                delete RelevanceBatchRevealedVoteCount[_ModB(_deletion_index)];
                // Delete the RandomQualitySubsets
                address[] memory allocated_workers = WorkersPerQualityBatch[
                    _ModB(_deletion_index)
                ];
                // delete the workers allocated to the quality batch 
                for (uint128 k = 0; k < allocated_workers.length; k++) {
                    //////////////////// FOR EACH WORKER ALLOCATED TO EACH BATCH
                    address _worker = allocated_workers[k];
                    // clear UserQualityVoteSubmission
                    delete UserQualityVoteSubmission[_ModB(_deletion_index)][_worker];
                }
                delete WorkersPerQualityBatch[_ModB(_deletion_index)];

                // delete the workers allocated to the relevance batch
                address[] memory allocated_workers_2 = WorkersPerRelevanceBatch[
                    _ModB(_deletion_index)
                ];
                for (uint128 k = 0; k < allocated_workers_2.length; k++) {
                    //////////////////// FOR EACH WORKER ALLOCATED TO EACH BATCH
                    address _worker = allocated_workers_2[k];
                    // clear UserRelevanceVoteSubmission
                    delete UserRelevanceVoteSubmission[_ModB(_deletion_index)][_worker];
                }
                delete WorkersPerRelevanceBatch[_ModB(_deletion_index)];
                emit _DataBatchDeleted(_deletion_index);
                // Update Global Variable
                BatchDeletionCursor = BatchDeletionCursor + 1;
                require(
                    BatchDeletionCursor <= BatchCheckingCursor,
                    "BatchDeletionCursor <= BatchCheckingCursor assert invalidated"
                );
            }
        }
    }

    /**
     * @dev Destroy AllWorkersArray, important to release storage space if critical
     */
    function deleteWorkersAtIndex(uint256 index_) public onlyOwner {
        address worker_at_index = AllWorkersList[index_];
        address SwappedWorkerAtIndex = AllWorkersList[
            AllWorkersList.length - 1
        ];
        if (AllWorkersList.length >= 2) {
            AllWorkersList[index_] = SwappedWorkerAtIndex; // swap last worker to this new position
        }

        AllWorkersList.pop(); // pop last worker
        PopFromBusyWorkers(worker_at_index);
        PopFromAvailableWorkers(worker_at_index);
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
    function deleteManyWorkersAtIndex(uint256[] memory indices_)
        public
        onlyOwner
    {
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

    ///////////////  ---------------------------------------------------------------------
    ///////////////              TRIGGER NEW EPOCH: DEPEND ON QUALITY SYSTEM
    ///////////////  ---------------------------------------------------------------------

    function pushData(IDataSpotting.BatchMetadata memory batch_) external returns (bool) {
        require(
            msg.sender == Parameters.getSpottingSystem(),
            "only the appointed DataSpotting contract can ping the system"
        );
        IDataSpotting.BatchMetadata memory SpotBatch = batch_;
        //  ADDING NEW CHECKED QUALITY BATCH AS A NEW ITEM IN OUR QUALITY BATCH

        InputFilesMap[DataNonce] = QualityData({
            ipfs_hash: SpotBatch.batchIPFSfile,
            author: msg.sender,
            timestamp: uint64(block.timestamp),
            unverified_item_count: SpotBatch.item_count
        });

        uint128 _batch_counter = LastBatchCounter;
        // UPDATE STREAMING DATA BATCH STRUCTURE
        BatchMetadata storage current_data_batch = ProcessedBatch[
            _ModB(_batch_counter)
        ];
        if (
            current_data_batch.counter <
            Parameters.get_QUALITY_DATA_BATCH_SIZE()
        ) {
            current_data_batch.counter += 1;
        }
        if (
            current_data_batch.counter >=
            Parameters.get_QUALITY_DATA_BATCH_SIZE()
        ) {
            // batch is complete trigger new work round, new batch
            current_data_batch.complete = true;
            current_data_batch.quality_checked = false;
            current_data_batch.relevance_checked = false;
            LastBatchCounter += 1;
            delete ProcessedBatch[_ModB(LastBatchCounter)];
            // we indicate that the first Quality of the new batch, is the one we just built
            ProcessedBatch[_ModB(_batch_counter)].start_idx = DataNonce;
        }

        DataNonce = DataNonce + 1;
        emit _QualitySubmitted(DataNonce, SpotBatch.batchIPFSfile, msg.sender);

        AllTxsCounter += 1;
        return false;
    }

    /**
     * @notice Trigger potential Data Batches Validations & Work Allocations
     * @param iteration_count max number of iterations
     */
    function TriggerUpdate(uint128 iteration_count) public {
        require(
            IParametersManager(address(0)) != Parameters,
            "Parameters Manager must be set."
        );
        updateItemCount();
        TriggerValidation(iteration_count, TaskType.Quality);
        TriggerValidation(iteration_count, TaskType.Relevance);
        // Log off waiting users first
        processLogoffRequests(iteration_count);
        TriggerAllocations(iteration_count);
        _retrieveSFuel();
    }

    /**
     * @notice Trigger at most iteration_count Work Allocations (N workers on a Batch)
     * @param iteration_count max number of iterations
     */
    function TriggerAllocations(uint128 iteration_count) public {
        require(
            IParametersManager(address(0)) != Parameters,
            "Parameters Manager must be set."
        );
        // Log off waiting users first
        processLogoffRequests(iteration_count);
        // Then iterate as much as possible in the batches.
        if ((LastRandomSeed != getRandom())) {
            for (uint128 i = 0; i < iteration_count; i++) {
                bool progress = false;
                // IF CURRENT BATCH IS COMPLETE AND NOT ALLOCATED TO WORKERS TO BE CHECKED, THEN ALLOCATE!
                if (
                    ProcessedBatch[_ModB(AllocatedBatchCursor)].allocated_to_work !=
                    true &&
                    availableWorkers.length >=
                    Parameters.get_QUALITY_MIN_CONSENSUS_WORKER_COUNT() &&
                    ProcessedBatch[_ModB(AllocatedBatchCursor)].complete &&
                    (AllocatedBatchCursor - BatchCheckingCursor <=
                        MAX_ONGOING_JOBS)
                    // number of allocated/processed batchs must not exceed this number
                ) {
                    AllocateWork(TaskType.Quality);
                    AllocateWork(TaskType.Relevance);
                    progress = true;
                }
                if (!progress) {
                    // break from the loop if no more progress
                    break;
                }
            }
        }
        _retrieveSFuel();
    }

    /**
     * @notice Trigger at most iteration_count Ended ProcessedBatch validations
     * @param iteration_count max number of iterations
     */
    function TriggerValidation(uint128 iteration_count, TaskType taskType) public {
        require(
            IParametersManager(address(0)) != Parameters,
            "Parameters Manager must be set."
        );
        uint128 PrevCursor = BatchCheckingCursor;
        for (uint128 i = 0; i < iteration_count; i++) {
            uint128 CurrentCursor = PrevCursor + i;
            // IF CURRENT BATCH IS ALLOCATED TO WORKERS AND VOTE HAS ENDED, TRIGGER VALIDATION
            if (
                ProcessedBatch[_ModB(CurrentCursor)].allocated_to_work &&
                (DataEnded(CurrentCursor, taskType) ||
                    (ProcessBatchInfo[_ModB(CurrentCursor)].unrevealed_quality_workers == 0))
            ) {
                // check if the batch is already validated
                if (!ProcessedBatch[_ModB(CurrentCursor)].quality_checked) {
                    ValidateBatch(CurrentCursor, taskType);
                }
                // increment BatchCheckingCursor if possible
                if (CurrentCursor == BatchCheckingCursor + 1) {
                    BatchCheckingCursor = BatchCheckingCursor + 1;
                    require(
                        BatchCheckingCursor <= AllocatedBatchCursor,
                        "BatchCheckingCursor <= AllocatedBatchCursor assert invalidated"
                    );
                }
            }
            // Garbage collect if the offset [Deletion - Checking Cursor] > NB_BATCH_TO_TRIGGER_GARBAGE_COLLECTION
            if (
                BatchDeletionCursor + NB_BATCH_TO_TRIGGER_GARBAGE_COLLECTION <
                BatchCheckingCursor
            ) {
                deleteOldData(1);
            }
        }
    }

    /**
     * @notice Checks if two strings are equal
     * @param _a string
     * @param _b string
     */
    function AreStringsEqual(string memory _a, string memory _b)
        public
        pure
        returns (bool)
    {
        if (
            keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b))
        ) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Update the global sliding counter of validated data, measuring the URL per TIMEFRAME (hour)
     */
    function updateItemCount() public {
        require(
            IParametersManager(address(0)) != Parameters,
            "Parameters Manager must be set."
        );
        uint256 last_timeframe_idx_ = ItemFlowManager.length - 1;
        uint256 mostRecentTimestamp_ = ItemFlowManager[last_timeframe_idx_]
            .timestamp;
        if (
            (uint64(block.timestamp) - mostRecentTimestamp_) >
            Parameters.get_QUALITY_TIMEFRAME_DURATION()
        ) {
            // cycle & move periods to the left
            for (uint256 i = 0; i < (ItemFlowManager.length - 1); i++) {
                ItemFlowManager[i] = ItemFlowManager[i + 1];
            }
            //update last timeframe with new values & reset counter
            ItemFlowManager[last_timeframe_idx_].timestamp = uint64(
                block.timestamp
            );
            ItemFlowManager[last_timeframe_idx_].counter = 0;
        }
    }
    // ================================================================================
    //                             Duplicates Registries Update
    // ================================================================================

    function triggerRegistriesUpdate(uint128 _DataBatchId) internal {}

    // ================================================================================
    // ================================================================================

    function updateQualityParameters(
        uint128 new_Quality_subset_count,
        uint128 new_Quality_coverage
    ) public onlyOwner {
        _Quality_subset_count = new_Quality_subset_count;
        _Quality_coverage = new_Quality_coverage;
    }

    /**
     * @dev Allocates Quality Work to a set of selected workers from the available pool.
     * This function selects workers, updates the allocated batch state, and assigns work to the selected workers.
     */
    function AllocateWork(TaskType taskType) internal {
        BatchMetadata storage allocated_batch = ProcessedBatch[
            _ModB(AllocatedBatchCursor)
        ];
        ProcessMetadata storage process_info = ProcessBatchInfo[
            _ModB(AllocatedBatchCursor)
        ];
        require(
            ProcessedBatch[_ModB(AllocatedBatchCursor)].complete,
            "Can't allocate work, the current batch is not complete"
        );
        require(
            !ProcessedBatch[_ModB(AllocatedBatchCursor)].allocated_to_work,
            "Can't allocate work, the current batch is already allocated"
        );

        if (
            (uint64(block.timestamp) - LastAllocationTime) >=
            Parameters.get_QUALITY_INTER_ALLOCATION_DURATION()
        ) {
            uint16 selected_k_workers = getSelectedWorkersCount();
            updateAllocatedBatchState(allocated_batch, process_info, selected_k_workers);
            // 1. Select workers
            address[] memory selected_workers_addresses = selectWorkers(
                selected_k_workers
            );
            // 2. Allocate Batch ID to selected workers

            // 3. If Quality, then allocate Quality work to selected workers
            
            if (taskType == TaskType.Quality) {
                uint128 _Quality_N = allocated_batch.counter * 100;
                uint128[][] memory allocated_random_subsets = getRandomSubsets(
                    _Quality_subset_count,
                    _Quality_N,
                    _Quality_coverage
                );
                // fill BatchSubset
                RandomQualitySubsets[
                    _ModB(AllocatedBatchCursor)
                ] = allocated_random_subsets;
            }
            // update selected workers states
            allocateWorkToWorkers(selected_workers_addresses, taskType);
            // post checks
            LastAllocationTime = uint64(block.timestamp);
            AllocatedBatchCursor += 1;
            LastRandomSeed = getRandom();
            AllTxsCounter += 1;
        }
    }


    // ================================================================================
    //                             Validate Data Batch
    // ================================================================================
    /**
     * @notice Validate data for the specified data batch.
     * @param _DataBatchId The ID of the data batch to be validated.
     */
    function ValidateBatch(uint128 _DataBatchId, TaskType taskType) internal {
        // BatchMetadata storage batch = ProcessedBatch[_ModB(_DataBatchId)];
        // ProcessMetadata storage process_info = ProcessBatchInfo[_ModB(_DataBatchId)];
        // 0. Check if initial conditions are met before validation process
        requireInitialQualityConditions(_DataBatchId, taskType);

        // 1. Get allocated workers
        address[] memory allocated_workers = WorkersPerQualityBatch[
            _ModB(_DataBatchId)
        ];

        // 2. Gather user submissions and vote inputs for the ProcessedBatch
        DataItemVote[] memory proposed_Quality_statuses = getWorkersQualitySubmissions(
            _DataBatchId,
            allocated_workers,
            taskType
        );

        // 3. Compute the majority submission & vote for the ProcessedBatch
        (
            DataItemVote memory confirmed_statuses,
            address[] memory workers_in_majority
        ) = getQualityQuorum(allocated_workers, proposed_Quality_statuses);

        // 7. Iterate through the minority_workers first
        for (uint256 i = 0; i < workers_in_majority.length; i++) {
            address worker_addr = workers_in_majority[i];
            bool has_worker_voted = UserQualityVoteSubmission[_ModB(_DataBatchId)][
                worker_addr
            ].revealed;
            // 8. Handle worker vote, update worker state and perform necessary actions
            handleWorkerQualityParticipation(worker_addr, has_worker_voted, true, taskType);
        }

        // 10. Update the ProcessedBatch state and counters based on the validation results
        updateValidatedQualityBatchState(_DataBatchId, confirmed_statuses, taskType);

        emit _BatchQualityValidated(_DataBatchId, confirmed_statuses);
    }


    /**
     * @notice Ensure the initial conditions are met for the data batch validation.
     * @param _DataBatchId The ID of the data batch.
     */
    function requireInitialQualityConditions(
        uint128 _DataBatchId,
        TaskType taskType
    ) private view {
        require(
            IParametersManager(address(0)) != Parameters,
            "Parameters Manager must be set."
        );
        require(
            Parameters.getAddressManager() != address(0),
            "AddressManager is null in Parameters"
        );
        require(
            Parameters.getRepManager() != address(0),
            "RepManager is null in Parameters"
        );
        require(
            Parameters.getRewardManager() != address(0),
            "RewardManager is null in Parameters"
        );
        bool early_batch_end = false;
        if (taskType == TaskType.Quality && (ProcessBatchInfo[_ModB(_DataBatchId)].unrevealed_quality_workers == 0)) {
            early_batch_end = true;
        } 
        else if(taskType == TaskType.Relevance && (ProcessBatchInfo[_ModB(_DataBatchId)].unrevealed_relevance_workers == 0)) {
            early_batch_end = true;
        }
        require(
            DataEnded(_DataBatchId, taskType) || early_batch_end,
            "_DataBatchId has not ended, or not every voters have voted"
        ); // votes need to be closed
        require(!ProcessedBatch[_ModB(_DataBatchId)].quality_checked, "_DataBatchId is already validated"); // votes need to be closed
    }

    /**
     * @notice Gather user submissions and vote inputs for the data batch validation.
     * @param _DataBatchId The ID of the data batch.
     * @param allocated_workers Array of worker addresses allocated to the data batch.
     */
    function getWorkersQualitySubmissions(
        uint128 _DataBatchId,
        address[] memory allocated_workers,
        TaskType taskType
    ) public view returns (DataItemVote[] memory) {
        DataItemVote[] memory proposed_Quality_statuses = new DataItemVote[](
            allocated_workers.length
        );

        // Iterate through all allocated workers for their Quality submissions
        for (uint256 i = 0; i < allocated_workers.length; i++) {
            address worker_addr_ = allocated_workers[i];
            // Store the worker's submitted data
            proposed_Quality_statuses[i] = QualitySubmissions[_ModB(_DataBatchId)][
                worker_addr_
            ];
        }

        return (proposed_Quality_statuses);
    }

    /**
     * @notice Compute the majority quorum for the data batch validation.
     * @param allocated_workers Array of worker addresses allocated to the data batch.
     * @param workers_statuses Array of DataItemVote representing each worker's votes.
     * @return confirmed_statuses The list of confirmed statuses as DataItemVote.
     * @return workers_in_majority The list of addresses indicating which worker has voted like the majority.
     */
    function getQualityQuorum(
        address[] memory allocated_workers,
        DataItemVote[] memory workers_statuses
    )
        public
        pure
        returns (
            DataItemVote memory confirmed_statuses,
            address[] memory workers_in_majority
        )
    {
        // Find the maximum index
        uint256 maxIndex = 0;
        for (uint256 i = 0; i < workers_statuses.length; i++) {
            for (uint256 j = 0; j < workers_statuses[i].indices.length; j++) {
                if (workers_statuses[i].indices[j] > maxIndex) {
                    maxIndex = workers_statuses[i].indices[j];
                }
            }
        }

        // Initialize variables
        uint256[][] memory statusCounts = new uint256[][](maxIndex + 1);
        for (uint256 i = 0; i <= maxIndex; i++) {
            statusCounts[i] = new uint256[](NB_UNIQUE_QUALITY_STATUSES);
        }
        uint256[] memory indexCounts = new uint256[](maxIndex + 1);
        bool[] memory isInMajority = new bool[](allocated_workers.length);

        // Count statuses for each index
        for (uint256 i = 0; i < workers_statuses.length; i++) {
            for (uint256 j = 0; j < workers_statuses[i].indices.length; j++) {
                uint8 index = workers_statuses[i].indices[j];
                uint8 status = workers_statuses[i].statuses[j];
                statusCounts[index][uint256(status)]++;
                indexCounts[index]++;
            }
        }

        // Determine the majority status for each index
        confirmed_statuses.indices = new uint8[](maxIndex + 1);
        confirmed_statuses.statuses = new uint8[](maxIndex + 1);

        for (uint256 i = 0; i <= maxIndex; i++) {
            uint256 maxStatusCount = 0;
            uint256 maxStatus = 0;
            for (uint256 s = 0; s < 4; s++) {
                if (statusCounts[i][s] > maxStatusCount) {
                    maxStatusCount = statusCounts[i][s];
                    maxStatus = s;
                }
            }
            confirmed_statuses.indices[i] = uint8(i);
            confirmed_statuses.statuses[i] = uint8(maxStatus);
        }

        // Determine which workers are in the majority
        for (uint256 i = 0; i < allocated_workers.length; i++) {
            isInMajority[i] = true;
            for (uint256 j = 0; j < workers_statuses[i].indices.length; j++) {
                uint8 index = workers_statuses[i].indices[j];
                if (workers_statuses[i].statuses[j] != confirmed_statuses.statuses[index]) {
                    isInMajority[i] = false;
                    break;
                }
            }
        }

        // Collect addresses of workers in the majority
        uint256 count = 0;
        for (uint256 i = 0; i < isInMajority.length; i++) {
            if (isInMajority[i]) {
                count++;
            }
        }

        workers_in_majority = new address[](count);
        count = 0;
        for (uint256 i = 0; i < isInMajority.length; i++) {
            if (isInMajority[i]) {
                workers_in_majority[count] = allocated_workers[i];
                count++;
            }
        }

        return (confirmed_statuses, workers_in_majority);
    }


    /**
     * @notice Update the majority batch count.
     * @param batch_ BatchMetadata storage reference for the data batch.
     * @param majorityBatchCount The majority batch count.
     * @param isCheckPassed True if the validation check passed, otherwise false.
     * @return The majority batch count
     */
    function updateMajorityBatchCount(
        BatchMetadata storage batch_,
        uint32 majorityBatchCount,
        bool isCheckPassed
    ) internal view returns (uint32) {
        if (!isCheckPassed) {
            return QUALITY_FILE_SIZE_MIN;
        } else {
            return
                uint32(
                    Math.min(
                        uint32(batch_.counter * QUALITY_FILE_SIZE_MIN),
                        majorityBatchCount
                    )
                );
        }
    }

    /**
     * @notice Reward a worker for their participation in the data batch validation.
     * @param worker_addr_ The address of the worker to be rewarded.
     */
    function rewardWorker(address worker_addr_) internal {
        IAddressManager _AddressManager = IAddressManager(
            Parameters.getAddressManager()
        );
        IRepManager _RepManager = IRepManager(Parameters.getRepManager());
        // IRewardManager _RewardManager = IRewardManager(Parameters.getRewardManager());

        address worker_master_addr_ = _AddressManager.FetchHighestMaster(
            worker_addr_
        );
        require(
            _RepManager.mintReputationForWork(
                Parameters.get_QUALITY_MIN_REP_DataValidation(),
                worker_master_addr_,
                ""
            ),
            "could not reward REP in Validate, 1.a"
        );
    }

    /**
     * @notice Handle worker vote during the data batch validation.
     * @param worker_addr_ The address of the worker.
     * @param has_worker_voted_ True if the worker has voted, otherwise false.
     * @param isInMajority True if worker in Majority
     */
    function handleWorkerQualityParticipation(
        address worker_addr_,
        bool has_worker_voted_,
        bool isInMajority,
        TaskType taskType
    ) internal {
        // Access worker state
        WorkerState storage worker_state = WorkersState[worker_addr_];

        // If the worker has indeed voted (committed & revealed)
        if (has_worker_voted_) {
            // Reset the no-vote counter for the worker
            worker_state.succeeding_novote_count = 0;

            // Reward the worker if they voted with the majority
            if (isInMajority) {
                rewardWorker(worker_addr_);
                worker_state.majority_counter += 1;
            } else {
                worker_state.minority_counter += 1;
            }
        }
        // If the worker has not voted (never revealed)
        else {
            // Increment the succeeding no-vote count for the worker
            worker_state.succeeding_novote_count += 1;

            // Force log off the worker if they have not voted multiple times in a row
            if (
                worker_state.succeeding_novote_count >=
                Parameters.get_MAX_SUCCEEDING_NOVOTES()
            ) {
                worker_state.registered = false;
                PopFromBusyWorkers(worker_addr_);
                PopFromAvailableWorkers(worker_addr_);
            }

            // If the worker has revealed, they are available again (revealing releases a given worker)
            // If the worker has not revealed, then the worker is still busy, move them from Busy to Available
            if (worker_state.registered) {
                // Only if the worker is still registered
                PopFromBusyWorkers(worker_addr_);
                PushInAvailableWorkers(worker_addr_);
            }

            worker_state.currently_working = false;
        }
    }

    /**
     * @notice Update the state of a validated data batch.
     * @param DataBatchId DataBatchId
     * @param confirmed_statuses The confirmed list of statuses
     */
    function updateValidatedQualityBatchState(
        uint128 DataBatchId,
        DataItemVote memory confirmed_statuses,
        TaskType taskType
    ) internal {
        BatchMetadata storage batch = ProcessedBatch[_ModB(DataBatchId)];
        ProcessMetadata storage process_info = ProcessBatchInfo[_ModB(DataBatchId)];
        // Update ProcessedBatch properties
        batch.quality_checked = true;

        // Update global counters
        AllTxsCounter += 1;
        NotCommitedCounter += process_info.uncommited_quality_workers;
        NotRevealedCounter += process_info.unrevealed_quality_workers;
    }

    /**
     * @dev Calculates the number of workers to be selected for allocation.
     * @return A uint16 representing the number of workers to be selected for work allocation.
     */
    function getSelectedWorkersCount() private view returns (uint16) {
        uint16 selected_k = uint16(
            Math.max(
                Math.min(
                    availableWorkers.length,
                    Parameters.get_QUALITY_MAX_CONSENSUS_WORKER_COUNT()
                ),
                Parameters.get_QUALITY_MIN_CONSENSUS_WORKER_COUNT()
            )
        );
        require(
            selected_k <= MAX_WORKER_ALLOCATED_PER_BATCH,
            "selected_k must be at most MAX_WORKER_ALLOCATED_PER_BATCH"
        );
        return selected_k;
    }

    /**
     * @dev Updates the allocated batch state with the selected workers' count.
     * @param allocated_batch A storage reference to the BatchMetadata struct being updated.
     * @param selected_k_workers A uint16 representing the number of selected workers for the current batch.
     */
    function updateAllocatedBatchState(
        BatchMetadata storage allocated_batch,
        ProcessMetadata storage process_info,
        uint16 selected_k_workers
    ) internal {
        process_info.uncommited_quality_workers = selected_k_workers;
        process_info.unrevealed_quality_workers = selected_k_workers;
        uint64 quality_commitEndDate = uint64(
            block.timestamp + Parameters.get_QUALITY_COMMIT_ROUND_DURATION()
        );
        uint64 quality_revealEndDate = uint64(
            quality_commitEndDate + Parameters.get_QUALITY_REVEAL_ROUND_DURATION()
        );
        uint64 relevance_commitEndDate = uint64(
            block.timestamp + Parameters.get_QUALITY_COMMIT_ROUND_DURATION()
        );
        uint64 relevance_revealEndDate = uint64(
            relevance_commitEndDate + Parameters.get_QUALITY_REVEAL_ROUND_DURATION()
        );
        allocated_batch.allocated_to_work = true;
        process_info.quality_commitEndDate = quality_commitEndDate;
        process_info.quality_revealEndDate = quality_revealEndDate;
        process_info.relevance_commitEndDate = relevance_commitEndDate;
        process_info.relevance_revealEndDate = relevance_revealEndDate;
    }

    /**
     * @dev Selects a set of workers from the available pool based on a specified count.
     * @param selected_k_workers A uint16 representing the number of workers to be selected for work allocation.
     * @return An array of addresses representing the selected workers.
     */
    function selectWorkers(uint16 selected_k_workers)
        private
        view
        returns (address[] memory)
    {
        uint256 n = availableWorkers.length;
        require(
            selected_k_workers >= 1 && n >= 1,
            "Fail during allocation: not enough workers"
        );
        uint256[] memory selected_workers_idx = random_selection(
            selected_k_workers,
            n
        );
        address[] memory selected_workers_addresses = new address[](
            selected_workers_idx.length
        );

        for (uint256 i = 0; i < selected_workers_idx.length; i++) {
            selected_workers_addresses[i] = availableWorkers[
                selected_workers_idx[i]
            ];
        }

        return selected_workers_addresses;
    }

    /**
     * @dev Allocates work to the specified set of workers and updates their state.
     * @param selected_workers_addresses An array of addresses representing the selected workers to be assigned work.
     */
    function allocateWorkToWorkers(address[] memory selected_workers_addresses, TaskType taskType)
        internal
    {
        uint128 _allocated_batch_cursor = AllocatedBatchCursor;
        // allocated workers per batch is always low (< 30). This loop can be considered O(1).
        for (uint256 i = 0; i < selected_workers_addresses.length; i++) {
            address selected_worker_ = selected_workers_addresses[i];
            WorkerState storage worker_state = WorkersState[selected_worker_];

            // clear existing values
            if (taskType == TaskType.Quality) {
                UserQualityVoteSubmission[_ModB(_allocated_batch_cursor)][selected_worker_]
                    .commited = false;
                UserQualityVoteSubmission[_ModB(_allocated_batch_cursor)][selected_worker_]
                    .revealed = false;
            } else if (taskType == TaskType.Relevance) {
                UserRelevanceVoteSubmission[_ModB(_allocated_batch_cursor)][selected_worker_]
                    .commited = false;
                UserRelevanceVoteSubmission[_ModB(_allocated_batch_cursor)][selected_worker_]
                    .revealed = false;
            }            

            // swap worker from available to busy, not to be picked again while working
            PopFromAvailableWorkers(selected_worker_);
            PushInBusyWorkers(selected_worker_); // set worker as busy
            if (taskType == TaskType.Quality) {
                WorkersPerQualityBatch[_ModB(_allocated_batch_cursor)].push(
                    selected_worker_
                );
            } else if (taskType == TaskType.Relevance) {
                WorkersPerRelevanceBatch[_ModB(_allocated_batch_cursor)].push(
                    selected_worker_
                );
            }
            // allocation of work depends on the taskType
            if (taskType == TaskType.Quality) {
                worker_state.allocated_quality_work_batch = _allocated_batch_cursor;
            } else if (taskType == TaskType.Relevance) {
                worker_state.allocated_relevance_work_batch = _allocated_batch_cursor;
            }
            worker_state.allocated_batch_counter += 1;
            worker_state.currently_working = true;

            emit _WorkAllocated(_allocated_batch_cursor, selected_worker_);
        }
    }

    /**
     * @notice To know if new work is available for worker's address user_
     * @param user_ user
     */
    function IsWorkAvailable(address user_, TaskType taskType) public view returns (bool) {
        bool new_work_available = false;
        WorkerState memory user_state = WorkersState[user_];
        if (taskType == TaskType.Quality){
            uint128 _currentUserBatch = user_state.allocated_quality_work_batch;
            if (_currentUserBatch == 0) {
                return false;
            }
            if (
                !didReveal(user_, _currentUserBatch, taskType) &&
                !CommitPeriodOver(_currentUserBatch, taskType)
            ) {
                new_work_available = true;
            }
        }
        else{
            uint128 _currentUserBatch = user_state.allocated_relevance_work_batch;
            if (_currentUserBatch == 0) {
                return false;
            }
            if (
                !didReveal(user_, _currentUserBatch, taskType) &&
                !CommitPeriodOver(_currentUserBatch, taskType)
            ) {
                new_work_available = true;
            }
        }
        return new_work_available;
    }

    /**
     * @notice Get the allocated batch subsets for a given BatchID (Quality Check)
     * @param DataBatchId DataBatchId
     */
     function GetAllocatedSubsets(uint128 DataBatchId) 
        public
        view
        returns (uint128, uint128[][] memory)
    {
        uint128 _DataBatchId = _ModB(DataBatchId);
        uint128[][] memory _currentWork = new uint128[][](2);
        _currentWork = RandomQualitySubsets[_DataBatchId];
        return (_DataBatchId, _currentWork);
    }

    /**
     * @notice Get newest work for user
     * @param user_ user
     */
    function GetCurrentQualityWork(address user_)
        public
        view
        returns (uint128, uint128[][] memory)
    {
        WorkerState memory user_state = WorkersState[user_];
        uint128 _currentUserBatch = user_state.allocated_quality_work_batch;
        uint128[][] memory _currentWork = new uint128[][](2);
        if (_currentUserBatch == 0) {
            return (_currentUserBatch, _currentWork);
        } else {
            _currentWork = RandomQualitySubsets[_ModB(_currentUserBatch)];
        }
        // if user has failed to commit and commitPeriod is Over, then currentWork is "missed".
        if (
            !didCommit(user_, _currentUserBatch, TaskType.Quality) &&
            CommitPeriodOver(_currentUserBatch, TaskType.Quality)
        ) {
            _currentUserBatch = 0;
        }

        return (_currentUserBatch, _currentWork);
    }

    /**
     * @notice Get the current relevance work for user
     * @param user_ user
     */
    function GetCurrentRelevanceWork(address user_)
        public
        view
        returns (uint128, uint128[][] memory)
    {
        WorkerState memory user_state = WorkersState[user_];
        uint128 _currentUserBatch = user_state.allocated_relevance_work_batch;
        uint128[][] memory _currentWork = new uint128[][](2);
        if (_currentUserBatch == 0) {
            return (_currentUserBatch, _currentWork);
        } else {
            _currentWork = RandomQualitySubsets[_ModB(_currentUserBatch)];
        }
        // if user has failed to commit and commitPeriod is Over, then currentWork is "missed".
        if (
            !didCommit(user_, _currentUserBatch, TaskType.Relevance) &&
            CommitPeriodOver(_currentUserBatch, TaskType.Relevance)
        ) {
            _currentUserBatch = 0;
        }

        return (_currentUserBatch, _currentWork);
    }

    // ================================================================================
    //                             INPUT DATA : QUALITY
    // ================================================================================
    struct Vote {
        uint256 index;
        uint8 status;
        uint8 extra;
    }

    /**
     * @notice Commits quality-check-vote on a ProcessedBatch
     * @param _DataBatchId ProcessedBatch ID
     * @param quality_signature_hash encrypted hash of the submitted indices and values
     * @param extra_ extra information (for indexing / archival purpose)
     */
    function commitQualityCheck(
        uint128 _DataBatchId,
        bytes32 quality_signature_hash, 
        string memory extra_
    ) public whenNotPaused {
        uint128 effective_batch_id = _ModB(_DataBatchId);
        require(
            IParametersManager(address(0)) != Parameters,
            "Parameters Manager must be set."
        );
        require(
            CommitPeriodActive(_DataBatchId, TaskType.Quality),
            "commit period needs to be open for this batchId"
        );
        require(
            !UserQualityVoteSubmission[effective_batch_id][msg.sender].commited,
            "User has already commited to this batchId"
        );
        require(
            isWorkerAllocatedToBatch(_DataBatchId, msg.sender, TaskType.Quality),
            "User needs to be allocated to this batch to commit on it"
        );
        require(
            Parameters.getAddressManager() != address(0),
            "AddressManager is null in Parameters"
        );

        // ---  Master/SubWorker Stake Management
        //_numTokens The number of tokens to be committed towards the target QualityData
        if (STAKING_REQUIREMENT_TOGGLE_ENABLED) {
            uint256 _numTokens = Parameters.get_QUALITY_MIN_STAKE();
            address _selectedAddress = SelectAddressForUser(
                msg.sender,
                _numTokens
            );
            // if tx sender has a master, then interact with his master's stake, or himself
            if (SystemStakedTokenBalance[_selectedAddress] < _numTokens) {
                uint256 remainder = _numTokens -
                    SystemStakedTokenBalance[_selectedAddress];
                requestAllocatedStake(remainder, _selectedAddress);
            }
        }

        // ----------------------- USER STATE UPDATE -----------------------        
        QualityHashes[effective_batch_id][msg.sender] = quality_signature_hash;
        UserQualityVoteSubmission[effective_batch_id][msg.sender].extra = extra_; //1 slot
        QualityBatchCommitedVoteCount[effective_batch_id] += 1;

        // ----------------------- WORKER STATE UPDATE -----------------------
        WorkerState storage worker_state = WorkersState[msg.sender];
        ProcessBatchInfo[effective_batch_id].uncommited_quality_workers =
            ProcessBatchInfo[effective_batch_id].uncommited_quality_workers -
            1;
        worker_state.last_interaction_date = uint64(block.timestamp);
        UserQualityVoteSubmission[effective_batch_id][msg.sender].commited = true;

        AllTxsCounter += 1;
        _retrieveSFuel();
        emit _QualityCheckCommitted(_DataBatchId, msg.sender);
    }

    /**
     * @notice Reveals quality-check-vote on a ProcessedBatch
     * @param _DataBatchId ProcessedBatch ID
     * @param clearSubmissions_ clear hash of the submitted IPFS vote
     * @param salt_ arbitraty integer used to hash the previous commit & verify the reveal
     */
    function revealQualityCheck(
        uint64 _DataBatchId,
        uint8[] memory clearIndices_,
        uint8[] memory clearSubmissions_,
        uint128 salt_
    ) public whenNotPaused {
        uint128 effective_batch_id = _ModB(_DataBatchId);
        // Make sure the reveal period is active
        require(
            RevealPeriodActive(effective_batch_id, TaskType.Relevance),
            "Reveal period not open for this DataID"
        );
        require(
            isWorkerAllocatedToBatch(effective_batch_id, msg.sender, TaskType.Quality),
            "User needs to be allocated to this batch to reveal on it"
        );
        require(
            UserRelevanceVoteSubmission[effective_batch_id][msg.sender].commited,
            "User has not commited before, thus can't reveal"
        );
        require(
            !UserRelevanceVoteSubmission[effective_batch_id][msg.sender].revealed,
            "User has already revealed, thus can't reveal"
        );
        // check _encryptedIndices and _encryptedSubmissions are of same length
        require(
            clearIndices_.length == clearSubmissions_.length,
            "clearIndices_ and clearSubmissions_ length mismatch"
        );
        // check if hash(clearIndices_, clearSubmissions_, salt_) == QualityHashes(commited_values)
        require(
            hashTwoUint8Arrays(clearIndices_, clearSubmissions_, salt_) ==
                QualityHashes[effective_batch_id][msg.sender],
            "hash(clearIndices_, clearSubmissions_, salt_) != QualityHashes(commited_values)"
        );

        // ----------------------- STORE SUBMITTED DATA --------------------
        QualitySubmissions[effective_batch_id][msg.sender].indices = clearIndices_;
        QualitySubmissions[effective_batch_id][msg.sender].statuses = clearSubmissions_;

        // ----------------------- USER/STATS STATE UPDATE -----------------------
        UserRelevanceVoteSubmission[effective_batch_id][msg.sender].revealed = true;
        if (clearSubmissions_.length == 0) {
            UserRelevanceVoteSubmission[effective_batch_id][msg.sender].vote = 0;
        } else {
            UserRelevanceVoteSubmission[effective_batch_id][msg.sender].vote = 1;
        }
        RelevanceBatchRevealedVoteCount[effective_batch_id] += 1;

        // ----------------------- WORKER STATE UPDATE -----------------------
        WorkerState storage worker_state = WorkersState[msg.sender];
        ProcessBatchInfo[effective_batch_id].unrevealed_quality_workers =
            ProcessBatchInfo[effective_batch_id].unrevealed_quality_workers -
            1;

        worker_state.last_interaction_date = uint64(block.timestamp);

        if (worker_state.registered) {
            // only if the worker is still registered
            worker_state.currently_working = false;
            PopFromBusyWorkers(msg.sender);
            PushInAvailableWorkers(msg.sender);
        }

        if (InstantRevealRewards) {
            address reveal_author_ = msg.sender;
            IAddressManager _AddressManager = IAddressManager(
                Parameters.getAddressManager()
            );
            IRepManager _RepManager = IRepManager(Parameters.getRepManager());
            IRewardManager _RewardManager = IRewardManager(
                Parameters.getRewardManager()
            );
            address reveal_author_master_ = _AddressManager.FetchHighestMaster(
                reveal_author_
            );
            uint256 repAmount = (Parameters
                .get_QUALITY_MIN_REP_DataValidation() * QUALITY_FILE_SIZE_MIN) /
                InstantRevealRewardsDivider;
            uint256 rewardAmount = (Parameters
                .get_QUALITY_MIN_REWARD_DataValidation() *
                QUALITY_FILE_SIZE_MIN) / InstantRevealRewardsDivider;
            require(
                _RepManager.mintReputationForWork(
                    repAmount,
                    reveal_author_master_,
                    ""
                ),
                "could not reward REP in revealQualityCheck, 1.a"
            );
            require(
                _RewardManager.ProxyAddReward(
                    rewardAmount,
                    reveal_author_master_
                ),
                "could not reward token in revealQualityCheck, 1.b"
            );
        }

        AllTxsCounter += 1;
        _retrieveSFuel();
        emit _QualityCheckRevealed(_DataBatchId, msg.sender);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////         Relevance Check      ////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Commits Relevance-check-vote on a ProcessedBatch
     * @param _DataBatchId ProcessedBatch ID
     * @param counts_signature_hash encrypted hash of the list of indices, values (and salt)
     * @param bounties_signature_hash encrypted hash of the list of indices, values (and salt)
     * @param duplicates_signature_hash encrypted hash of the list of indices, values (and salt)
     * @param _BatchCount Batch Count in number of items (in the aggregated IPFS hash)
     * @param extra_ extra information (for indexing / archival purpose)
     */
    function commitRelevanceCheck(
        uint128 _DataBatchId,
        bytes32 counts_signature_hash,
        bytes32 bounties_signature_hash,
        bytes32 duplicates_signature_hash, 
        uint32 _BatchCount,
        string memory extra_
    ) public whenNotPaused {        
        uint128 effective_batch_id = _ModB(_DataBatchId);
        require(
            IParametersManager(address(0)) != Parameters,
            "Parameters Manager must be set."
        );
        require(
            CommitPeriodActive(effective_batch_id, TaskType.Quality),
            "commit period needs to be open for this batchId"
        );
        require(
            !UserRelevanceVoteSubmission[effective_batch_id][msg.sender].commited,
            "User has already commited to this batchId"
        );
        require(
            isWorkerAllocatedToBatch(effective_batch_id, msg.sender, TaskType.Relevance),
            "User needs to be allocated to this batch to commit on it"
        );

        // ---  Master/SubWorker Stake Management
        //_numTokens The number of tokens to be committed towards the target QualityData
        uint256 _numTokens = Parameters.get_QUALITY_MIN_STAKE();
        if (STAKING_REQUIREMENT_TOGGLE_ENABLED) {
            address _selectedAddress = SelectAddressForUser(
                msg.sender,
                _numTokens
            );
            // if tx sender has a master, then interact with his master's stake, or himself
            if (SystemStakedTokenBalance[_selectedAddress] < _numTokens) {
                uint256 remainder = _numTokens -
                    SystemStakedTokenBalance[_selectedAddress];
                requestAllocatedStake(remainder, _selectedAddress);
            }
        }
        // ----------------------- STORE HASHES  -----------------------
        // Store encrypted hash for the 3 arrays
        UserEncryptedBaseCounts[effective_batch_id][msg.sender] = counts_signature_hash;
        UserEncryptedBountiesCounts[effective_batch_id][msg.sender] = bounties_signature_hash;
        UserEncryptedDuplicates[effective_batch_id][msg.sender] = duplicates_signature_hash;
        
        // ----------------------- USER STATE UPDATE -----------------------
        UserRelevanceVoteSubmission[effective_batch_id][msg.sender]
            .batchCount = _BatchCount; //1 slot
        UserRelevanceVoteSubmission[effective_batch_id][msg.sender].extra = extra_; //1 slot
        RelevanceBatchCommitedVoteCount[effective_batch_id] += 1;

        // ----------------------- WORKER STATE UPDATE -----------------------
        WorkerState storage worker_state = WorkersState[msg.sender];
        ProcessBatchInfo[effective_batch_id].uncommited_quality_workers =
            ProcessBatchInfo[effective_batch_id].uncommited_quality_workers -
            1;
        worker_state.last_interaction_date = uint64(block.timestamp);
        UserRelevanceVoteSubmission[effective_batch_id][msg.sender].commited = true;

        AllTxsCounter += 1;
        _retrieveSFuel();
        emit _RelevanceCheckCommitted(effective_batch_id, msg.sender);
    }

    /**
     * @notice Reveals quality-check-vote on a ProcessedBatch
     * @param _DataBatchId ProcessedBatch ID
     * @param base_counts_indices_ list of uint8 representing base count indices
     * @param base_counts_values_ list of uint8 representing base count values
     * @param bounties_counts_indices_ list of uint8 representing bounties count indices
     * @param bounties_counts_values_ list of uint8 representing bounties count values
     * @param duplicates_counts_indices_ list of uint8 representing duplicate count indices
     * @param duplicates_counts_values_ list of uint8 representing base count values
     * @param salt_ arbitraty integer used to hash the previous commit & verify the reveal
     */
    function revealRelevanceCheck(
        uint64 _DataBatchId,
        uint8[] memory base_counts_indices_,
        uint8[] memory base_counts_values_,
        uint8[] memory bounties_counts_indices_,
        uint8[] memory bounties_counts_values_,
        uint8[] memory duplicates_counts_indices_,
        uint8[] memory duplicates_counts_values_,
        uint128 salt_
    ) public whenNotPaused {
        uint128 effective_batch_id = _ModB(_DataBatchId);
        // Make sure the reveal period is active
        require(
            RevealPeriodActive(effective_batch_id, TaskType.Relevance),
            "Reveal period not open for this DataID"
        );
        require(
            isWorkerAllocatedToBatch(effective_batch_id, msg.sender, TaskType.Relevance),
            "User needs to be allocated to this batch to reveal on it"
        );
        require(
            UserRelevanceVoteSubmission[effective_batch_id][msg.sender].commited,
            "User has not commited before, thus can't reveal"
        );
        require(
            !UserRelevanceVoteSubmission[effective_batch_id][msg.sender].revealed,
            "User has already revealed, thus can't reveal"
        );
        // check countsclearIndices_ and counts_clearValues are of same length
        require(
            base_counts_indices_.length == base_counts_values_.length,
            "countsclearIndices_ length mismatch"
        );
        // check bountiesclearIndices_ and bounties_clearValues are of same length
        require(
            bounties_counts_indices_.length == bounties_counts_values_.length,
            "bountiesclearIndices_ length mismatch"
        );
        // check duplicatesclearIndices_ and duplicates_clearValues are of same length
        require(
            duplicates_counts_indices_.length == duplicates_counts_values_.length,
            "duplicatesclearIndices_ length mismatch"
        );
        // Handling Counts
        require(
            hashTwoUint8Arrays(base_counts_indices_, base_counts_values_, salt_) ==
                UserEncryptedBaseCounts[effective_batch_id][msg.sender],
            "Base arrays don't match the previously commited hash"
        );
        // Handling Bounties
        require(
            hashTwoUint8Arrays(base_counts_indices_, bounties_counts_values_, salt_) ==
                UserEncryptedBountiesCounts[effective_batch_id][msg.sender],
            "Bounties arrays don't match the previously commited hash"
        );
        // Handling Duplicates counts
        require(
            hashTwoUint8Arrays(duplicates_counts_indices_, duplicates_counts_values_, salt_) ==
                UserEncryptedDuplicates[effective_batch_id][msg.sender],
            "Duplicate arrays don't match the previously commited hash"
        );

        // ----------------------- STORE THE SUBMITTED VALUES  -----------------------
        // Store encrypted hash for the 3 arrays

        // ----------------------- USER STATE UPDATE -----------------------
        UserRelevanceVoteSubmission[effective_batch_id][msg.sender].revealed = true;
        UserRelevanceVoteSubmission[effective_batch_id][msg.sender].vote = 1;
        RelevanceBatchRevealedVoteCount[effective_batch_id] += 1;

        // ----------------------- WORKER STATE UPDATE -----------------------
        WorkerState storage worker_state = WorkersState[msg.sender];
        ProcessBatchInfo[effective_batch_id].unrevealed_quality_workers =
            ProcessBatchInfo[effective_batch_id].unrevealed_quality_workers -
            1;

        worker_state.last_interaction_date = uint64(block.timestamp);

        if (worker_state.registered) {
            // only if the worker is still registered, of course.
            // PUT BACK THE WORKER AS AVAILABLE
            // Mark the current work back to 0, to allow worker to unregister before new work.
            worker_state.allocated_relevance_work_batch = 0;
            PopFromBusyWorkers(msg.sender);
            PushInAvailableWorkers(msg.sender);
        }

        if (InstantRevealRewards) {
            address reveal_author_ = msg.sender;
            IAddressManager _AddressManager = IAddressManager(
                Parameters.getAddressManager()
            );
            IRepManager _RepManager = IRepManager(Parameters.getRepManager());
            IRewardManager _RewardManager = IRewardManager(
                Parameters.getRewardManager()
            );
            address reveal_author_master_ = _AddressManager.FetchHighestMaster(
                reveal_author_
            );
            uint256 repAmount = (Parameters
                .get_QUALITY_MIN_REP_DataValidation() * QUALITY_FILE_SIZE_MIN) /
                InstantRevealRewardsDivider;
            uint256 rewardAmount = (Parameters
                .get_QUALITY_MIN_REWARD_DataValidation() *
                QUALITY_FILE_SIZE_MIN) / InstantRevealRewardsDivider;
            require(
                _RepManager.mintReputationForWork(
                    repAmount,
                    reveal_author_master_,
                    ""
                ),
                "could not reward REP in revealQualityCheck, 1.a"
            );
            require(
                _RewardManager.ProxyAddReward(
                    rewardAmount,
                    reveal_author_master_
                ),
                "could not reward token in revealQualityCheck, 1.b"
            );
        }

        AllTxsCounter += 1;
        _retrieveSFuel();
        emit _RelevanceCheckRevealed(effective_batch_id, msg.sender);
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
        require(
            Parameters.getStakeManager() != address(0),
            "StakeManager is null in Parameters"
        );
        IStakeManager _StakeManager = IStakeManager(
            Parameters.getStakeManager()
        );
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
     * @notice get BytesUsed (storage space), monitored by the contract
     *         can be approximative
     */
    function getBytesUsed() public view returns (uint256 storage_size) {
        return BytesUsed;
    }

    /**
     * @notice get Locked Token for the current Contract (WorkSystem)
     * @param user_ The user address
     */
    function getSystemTokenBalance(address user_)
        public
        view
        returns (uint256 tokens)
    {
        return (uint256(SystemStakedTokenBalance[user_]));
    }

    /**
     * @notice Get Total Accepted Batches
     */
    function getAcceptedBatchesCount() public view returns (uint128 count) {
        return AcceptedBatchsCounter;
    }

    /**
     * @notice Get Total Rejected Batches
     */
    function getRejectedBatchesCount() public view returns (uint128 count) {
        return RejectedBatchsCounter;
    }

    // ================================================================================
    //                              GETTERS - DATA
    // ================================================================================

    /**
     * @notice get all item counts for all batches between batch indices A and B (a < B)
     * @param _DataBatchId_a ID of the starting batch
     * @param _DataBatchId_b ID of the ending batch (included)
     */
    function getBatchCountForBatch(
        uint128 _DataBatchId_a,
        uint128 _DataBatchId_b
    )
        public
        view
        returns (uint128 AverageURLCount, uint128[] memory batchCounts)
    {
        require(
            _DataBatchId_a > 0 && _DataBatchId_a < _DataBatchId_b,
            "Input boundaries are invalid"
        );
        uint128 _total_batchs_count = 0;
        uint128 _batch_amount = _DataBatchId_b - _DataBatchId_a + 1;

        uint128[] memory _batch_counts_list = new uint128[](_batch_amount);

        for (uint128 i = 0; i < _batch_amount; i++) {
            BatchMetadata memory batch_ = ProcessedBatch[_ModB(i + _DataBatchId_a)];
            _total_batchs_count += batch_.item_count;
            _batch_counts_list[i] = batch_.item_count;
        }

        uint128 _average_batch_count = _total_batchs_count / _batch_amount;

        return (_average_batch_count, _batch_counts_list);
    }

    /**
     * @notice get the From information for a given batch
     * @param _DataBatchId ID of the batch
     */
    function getExtrasForQualityBatch(uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (string[] memory)
    {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        if(taskType == TaskType.Quality) {
            address[] memory allocated_workers = WorkersPerQualityBatch[
                _ModB(_DataBatchId)
            ];
            string[] memory from_list = new string[](allocated_workers.length);

            for (uint128 i = 0; i < allocated_workers.length; i++) {
                from_list[i] = UserQualityVoteSubmission[_ModB(_DataBatchId)][
                    allocated_workers[i]
                ].extra;
            }
            return from_list;
        } else if(taskType == TaskType.Relevance) {
            address[] memory allocated_workers = WorkersPerRelevanceBatch[
                _ModB(_DataBatchId)
            ];
            string[] memory from_list = new string[](allocated_workers.length);

            for (uint128 i = 0; i < allocated_workers.length; i++) {
                from_list[i] = UserRelevanceVoteSubmission[_ModB(_DataBatchId)][
                    allocated_workers[i]
                ].extra;
            }
            return from_list;
        }
    }

    /**
     * @notice get all Submissions on a given batch
     * @param _DataBatchId ID of the batch
     */
    function getSubmissionsForBatch(uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (uint128[] memory)
    {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        if(taskType == TaskType.Quality) {
            address[] memory allocated_workers = WorkersPerQualityBatch[
                _ModB(_DataBatchId)
            ];
            uint128[] memory votes_list = new uint128[](allocated_workers.length);

            for (uint128 i = 0; i < allocated_workers.length; i++) {
                votes_list[i] = UserQualityVoteSubmission[_ModB(_DataBatchId)][
                    allocated_workers[i]
                ].vote;
            }
            return votes_list;
        } else if(taskType == TaskType.Relevance) {
            address[] memory allocated_workers = WorkersPerRelevanceBatch[
                _ModB(_DataBatchId)
            ];
            uint128[] memory votes_list = new uint128[](allocated_workers.length);

            for (uint128 i = 0; i < allocated_workers.length; i++) {
                votes_list[i] = UserRelevanceVoteSubmission[_ModB(_DataBatchId)][
                    allocated_workers[i]
                ].vote;
            }
            return votes_list;
        }

    }

    /**
     * @notice Get all current workers
     */
    function getActiveWorkersCount() public view returns (uint256 numWorkers) {
        return (uint256(availableWorkers.length + busyWorkers.length));
    }

    /**
     * @notice Get all available (idle) workers
     */
    function getAvailableWorkersCount()
        public
        view
        returns (uint256 numWorkers)
    {
        return (uint256(availableWorkers.length));
    }

    /**
     * @notice Get all busy workers
     */
    function getBusyWorkersCount() public view returns (uint256 numWorkers) {
        return (uint256(busyWorkers.length));
    }

    // ----------------------------------------------------
    // ----------------------------------------------------
    //                     Data HELPERS
    // ----------------------------------------------------
    // ----------------------------------------------------

    /**
     * @notice Determines if QualityData is over
     * @dev Checks isExpired for specified QualityData's revealEndDate
     * @return ended Boolean indication of whether Dataing period is over
     */
    function DataEnded(uint128 _DataBatchId, TaskType taskType) public view returns (bool ended) {
        if(taskType == TaskType.Quality) {
            isExpired(ProcessBatchInfo[_ModB(_DataBatchId)].quality_revealEndDate) ||
            (CommitPeriodOver(_DataBatchId, taskType) &&
                QualityBatchCommitedVoteCount[_ModB(_DataBatchId)] == 0);
        } else if(taskType == TaskType.Relevance) {
            isExpired(ProcessBatchInfo[_ModB(_DataBatchId)].relevance_revealEndDate) ||
            (CommitPeriodOver(_DataBatchId, taskType) &&
                RelevanceBatchCommitedVoteCount[_ModB(_DataBatchId)] == 0);
        }
    }

    /**
     * @notice get Last Data Id
     * @return DataId
     */
    function getLastDataId() public view returns (uint256 DataId) {
        return DataNonce;
    }

    /**
     * @notice get Last Batch Id
     * @return LastBatchId
     */
    function getLastBatchId() public view returns (uint256 LastBatchId) {
        return LastBatchCounter;
    }

    /**
     * @notice get Last Checked Batch Id
     * @return LastCheckedBatchId
     */
    function getLastCheckedBatchId()
        public
        view
        returns (uint256 LastCheckedBatchId)
    {
        return BatchCheckingCursor;
    }

    /**
     * @notice getLastAllocatedBatchId
     * @return LastAllocatedBatchId
     */
    function getLastAllocatedBatchId()
        public
        view
        returns (uint256 LastAllocatedBatchId)
    {
        return AllocatedBatchCursor;
    }

    /**
     * @notice get ProcessedBatch By ID
     * @return batch as BatchMetadata struct
     */
    function getBatchByID(uint128 _DataBatchId)
        public
        view
        returns (BatchMetadata memory batch)
    {
        require(DataExists(_DataBatchId));
        return ProcessedBatch[_ModB(_DataBatchId)];
    }

    /**
     * @dev Returns all worker addresses between index A_ and index B
     * @param A_ Address of user to check against
     * @param B_ Integer identifier associated with target QualityData
     * @return workers array of workers of size (B_-A_+1)
     */
    function getAllWorkersBetweenIndex(uint256 A_, uint256 B_)
        public
        view
        returns (address[] memory workers)
    {
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
    function getAllWorkersLength() public view returns (uint256 length) {
        return AllWorkersList.length;
    }

    /**
     * @notice get Data By ID
     * @return data as QualityData struct
     */
    function getDataByID(uint128 _DataId)
        public
        view
        returns (QualityData memory data)
    {
        return InputFilesMap[_ModS(_DataId)];
    }

    /**
     * @notice getCounter
     * @return Counter of all "accepted transactions"
     */
    function getTxCounter() public view returns (uint256 Counter) {
        return AllTxsCounter;
    }

    /**
     * @notice getCounter
     * @return Counter of the last Dataed a user started
     */
    function getItemCounter() public view returns (uint256 Counter) {
        return AllItemCounter;
    }

    /**
     * @notice Determines DataCommitEndDate
     * @return commitEndDate indication of whether Dataing period is over
     */
    function DataCommitEndDate(uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (uint256 commitEndDate)
    {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");
        if (taskType == TaskType.Quality) {
            return ProcessBatchInfo[_ModB(_DataBatchId)].quality_commitEndDate;
        } else if (taskType == TaskType.Relevance) {
            return ProcessBatchInfo[_ModB(_DataBatchId)].relevance_commitEndDate;
        }
    }

    /**
     * @notice Determines DataRevealEndDate
     * @return revealEndDate indication of whether Dataing period is over
     */
    function DataRevealEndDate(uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (uint256 revealEndDate)
    {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        if (taskType == TaskType.Quality) {
            return ProcessBatchInfo[_ModB(_DataBatchId)].quality_revealEndDate;
        } else if (taskType == TaskType.Relevance) {
            return ProcessBatchInfo[_ModB(_DataBatchId)].relevance_revealEndDate;
        }
    }

    /**
     * @notice Checks if the commit period is still active for the specified QualityData
     * @dev Checks isExpired for the specified QualityData's commitEndDate
     * @param _DataBatchId Integer identifier associated with target QualityData
     * @return active Boolean indication of isCommitPeriodActive for target QualityData
     */
    function CommitPeriodActive(uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (bool active)
    {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        if (taskType == TaskType.Quality) {
            return
                !isExpired(ProcessBatchInfo[_ModB(_DataBatchId)].quality_commitEndDate) &&
                (ProcessBatchInfo[_ModB(_DataBatchId)].uncommited_quality_workers > 0);
        } else if (taskType == TaskType.Relevance) {
            return
                !isExpired(ProcessBatchInfo[_ModB(_DataBatchId)].relevance_commitEndDate) &&
                (ProcessBatchInfo[_ModB(_DataBatchId)].uncommited_relevance_workers > 0);
        }
    }

    /**
     * @notice Checks if the commit period is over
     * @dev Checks isExpired for the specified QualityData's commitEndDate
     * @param _DataBatchId Integer identifier associated with target QualityData
     * @return active Boolean indication of isCommitPeriodOver for target QualityData
     */
    function CommitPeriodOver(uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (bool active)
    {
        if (!DataExists(_DataBatchId)) {
            return false;
        } else {
            // a commitPeriod is over if time has expired OR if revealPeriod for the same _DataBatchId is true
            
            if (taskType == TaskType.Quality) {
                return
                    isExpired(ProcessBatchInfo[_ModB(_DataBatchId)].quality_commitEndDate) ||
                    RevealPeriodActive(_DataBatchId, taskType);
            } else if (taskType == TaskType.Relevance) {
                return
                    isExpired(ProcessBatchInfo[_ModB(_DataBatchId)].relevance_commitEndDate) ||
                    RevealPeriodActive(_DataBatchId, taskType);
            }
        }
    }

    /**
     * @notice Checks if the commit period is still active for the specified QualityData
     * @dev Checks isExpired for the specified QualityData's commitEndDate
     * @param _DataBatchId Integer identifier associated with target QualityData
     * @return remainingTime Integer
     */
    function remainingCommitDuration(uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (uint256 remainingTime)
    {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");
        uint64 _remainingTime = 0;
        if (CommitPeriodActive(_DataBatchId, taskType)) {
            if(taskType == TaskType.Quality) {
                _remainingTime =
                    ProcessBatchInfo[_ModB(_DataBatchId)].quality_commitEndDate -
                    uint64(block.timestamp);
            } else if(taskType == TaskType.Relevance) {
                _remainingTime =
                    ProcessBatchInfo[_ModB(_DataBatchId)].relevance_commitEndDate -
                    uint64(block.timestamp);
            }
        }
        return _remainingTime;
    }

    /**
     * @notice Checks if the reveal period is still active for the specified QualityData
     * @dev Checks isExpired for the specified QualityData's revealEndDate
     * @param _DataBatchId Integer identifier associated with target QualityData
     */
    function RevealPeriodActive(uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (bool active)
    {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");

        if(taskType == TaskType.Quality) {
            return
                !isExpired(ProcessBatchInfo[_ModB(_DataBatchId)].quality_revealEndDate) &&
                !CommitPeriodActive(_DataBatchId, taskType);
        } else if(taskType == TaskType.Relevance) {
            return
                !isExpired(ProcessBatchInfo[_ModB(_DataBatchId)].relevance_revealEndDate) &&
                !CommitPeriodActive(_DataBatchId, taskType);
        }
    }

    /**
     * @notice Checks if the reveal period is over
     * @dev Checks isExpired for the specified QualityData's revealEndDate
     * @param _DataBatchId Integer identifier associated with target QualityData
     */
    function RevealPeriodOver(uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (bool active)
    {
        if (!DataExists(_DataBatchId)) {
            return false;
        } else {
            
            if(taskType == TaskType.Quality) {
                // a commitPeriod is Over if : time has expired OR if revealPeriod for the same _DataBatchId is true
                return
                    isExpired(ProcessBatchInfo[_ModB(_DataBatchId)].quality_revealEndDate) ||
                    ProcessBatchInfo[_ModB(_DataBatchId)].unrevealed_quality_workers == 0;
            } else if(taskType == TaskType.Relevance) {
                // a commitPeriod is Over if : time has expired OR if revealPeriod for the same _DataBatchId is true
                return
                    isExpired(ProcessBatchInfo[_ModB(_DataBatchId)].relevance_revealEndDate) ||
                    ProcessBatchInfo[_ModB(_DataBatchId)].unrevealed_relevance_workers == 0;
            }
        }
    }

    /**
     * @notice Checks if the commit period is still active for the specified QualityData
     * @dev Checks isExpired for the specified QualityData's commitEndDate
     * @param _DataBatchId Integer identifier associated with target QualityData
     * @return remainingTime Integer indication of isQualityCommitPeriodActive for target QualityData
     */
    function RemainingRevealDuration(uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (uint256 remainingTime)
    {
        require(DataExists(_DataBatchId), "_DataBatchId must exist");
        uint256 _remainingTime = 0;
        if(taskType == TaskType.Quality) {
            if (RevealPeriodActive(_DataBatchId, taskType)) {
                _remainingTime =
                    ProcessBatchInfo[_ModB(_DataBatchId)].quality_revealEndDate -
                    block.timestamp;
            }
        } else if(taskType == TaskType.Relevance) {
            if (RevealPeriodActive(_DataBatchId, taskType)) {
                _remainingTime =
                    ProcessBatchInfo[_ModB(_DataBatchId)].relevance_revealEndDate -
                    block.timestamp;
            }
        }
        return _remainingTime;
    }

    /**
     * @dev Checks if user has committed for specified QualityData
     * @param _voter Address of user to check against
     * @param _DataBatchId Integer identifier associated with target QualityData
     * @return committed Boolean indication of whether user has committed
     */
    function didCommit(address _voter, uint128 _DataBatchId, TaskType taskType)
        public
        view
        returns (bool committed)
    {
        if (taskType == TaskType.Quality) {
            return UserQualityVoteSubmission[_ModB(_DataBatchId)][_voter].commited;
        } else if (taskType == TaskType.Relevance) {
            return UserRelevanceVoteSubmission[_ModB(_DataBatchId)][_voter].commited;
        }
    }

    /**
     * @dev Checks if user has revealed for specified QualityData
     * @param _voter Address of user to check against
     * @param _DataBatchId Integer identifier associated with target QualityData
     * @return revealed Boolean indication of whether user has revealed
     */
    function didReveal(address _voter, uint128 _DataBatchId, TaskType taskType )
        public
        view
        returns (bool revealed)
    {
        if (taskType == TaskType.Quality) {
            return UserQualityVoteSubmission[_ModB(_DataBatchId)][_voter].revealed;
        } else if (taskType == TaskType.Relevance) {
            return UserRelevanceVoteSubmission[_ModB(_DataBatchId)][_voter].revealed;
        }
    }

    /**
     * @dev Checks if a QualityData exists
     * @param _DataBatchId The DataID whose existance is to be evaluated.
     * @return exists Boolean Indicates whether a QualityData exists for the provided DataID
     */
    function DataExists(uint128 _DataBatchId)
        public
        view
        returns (bool exists)
    {
        return (ProcessedBatch[_ModB(_DataBatchId)].complete);
    }

    function AmIRegistered() public view returns (bool passed) {
        return WorkersState[msg.sender].registered;
    }

    /**
     * @dev Gets the bytes32 commitHash property of target QualityData
     * @param _clearVote vote Option
     * @param salt_ is the salt
     * @return keccak256hash Bytes32 hash property attached to target QualityData
     */
    function getEncryptedHash(uint256 _clearVote, uint256 salt_)
        public
        pure
        returns (bytes32 keccak256hash)
    {
        return keccak256(abi.encodePacked(_clearVote, salt_));
    }

    function getEncryptedListHash(uint8[] memory values, uint256 salt_)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(values, salt_));
    }

    /**
     * @dev Gets the bytes32 commitHash property of target QualityData
     * @param _hash ipfs hash of aggregated data in a string
     * @param salt_ is the salt
     * @return keccak256hash Bytes32 hash property attached to target QualityData
     */
    function getEncryptedStringHash(string memory _hash, uint256 salt_)
        public
        pure
        returns (bytes32 keccak256hash)
    {
        return keccak256(abi.encode(_hash, salt_));
    }

    // ----------------
    // GENERAL HELPERS:
    // ----------------

    /**
     * @dev Checks if an expiration date has been reached
     * @param _terminationDate Integer timestamp of date to compare current timestamp with
     * @return expired Boolean indication of whether the terminationDate has passed
     */
    function isExpired(uint256 _terminationDate)
        public
        view
        returns (bool expired)
    {
        return (block.timestamp > _terminationDate);
    }

        /**
     * @dev Hashes an array of bytes32 values with a salt.
     * @param data The bytes32 array to be hashed.
     * @param salt The uint128 salt to be used in the hash.
     * @return The keccak256 hash of the encoded bytes32 array and the salt.
     *
     * This function takes an array of bytes32 values and a uint128 salt,
     * encodes them using Solidity's abi.encodePacked function, and then
     * computes the keccak256 hash. The inclusion of a salt ensures that
     * the hash output is unique even for identical input arrays.
     */
    function hashBytes32Array(bytes32[] memory data, uint128 salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(data, salt));
    }

    /**
     * @dev Hashes an array of uint8 values with a salt.
     * @param data The uint8 array to be hashed.
     * @param salt The uint128 salt to be used in the hash.
     * @return The keccak256 hash of the encoded uint8 array and the salt.
     *
     * Similar to hashBytes32Array, this function takes an array of uint8 values
     * and a uint128 salt, encodes them using abi.encodePacked, and computes
     * the keccak256 hash. The use of a salt enhances the security of the hash.
     */
    function hashUint8Array(uint8[] memory data, uint128 salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(data, salt));
    }

    /**
     * @dev Hashes an array of uint128 values with a salt.
     * @param data The uint128 array to be hashed.
     * @param salt The uint128 salt to be used in the hash.
     * @return The keccak256 hash of the encoded uint128 array and the salt.
     *
     * This function takes an array of uint128 values and a uint128 salt,
     * encodes them using abi.encodePacked, and computes the keccak256 hash.
     * The salt adds an extra layer of security, ensuring unique hash outputs.
     */
    function hashUint128Array(uint128[] memory data, uint128 salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(data, salt));
    }

    /**
    * @dev Hashes two arrays of uint8 values with a salt.
    * @param data1 The first uint8 array to be hashed.
    * @param data2 The second uint8 array to be hashed.
    * @param salt The uint128 salt to be used in the hash.
    * @return The keccak256 hash of the encoded uint8 arrays and the salt.
    *
    * This function takes two arrays of uint8 values and a uint128 salt,
    * encodes them using abi.encodePacked, and computes the keccak256 hash.
    * The salt adds an extra layer of security, ensuring unique hash outputs
    * even for identical array inputs.
    */
    function hashTwoUint8Arrays(uint8[] memory data1, uint8[] memory data2, uint128 salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(data1, data2, salt));
    }

    /**
    * @dev Hashes two arrays of uint128 values with a salt.
    * @param data1 The first uint128 array to be hashed.
    * @param data2 The second uint128 array to be hashed.
    * @param salt The uint128 salt to be used in the hash.
    * @return The keccak256 hash of the encoded uint128 arrays and the salt.
    *
    * This function takes two arrays of uint128 values and a uint128 salt,
    * encodes them using abi.encodePacked, and computes the keccak256 hash.
    * The inclusion of a salt ensures that the hash output is unique even
    * for identical array inputs.
    */
    function hashTwoUint128Arrays(uint128[] memory data1, uint128[] memory data2, uint128 salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(data1, data2, salt));
    }

}
