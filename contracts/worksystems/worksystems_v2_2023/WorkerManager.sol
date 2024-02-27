// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8 .20;

/**
 * @title WorkerManager
 * @author Mathias Dail - CTO @ Exorde Labs 2024
 */

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./FuelRetriever.sol";
import "./interfaces/IParametersManager.sol";
import "./interfaces/IStakeManager.sol";
import "./interfaces/IAddressManager.sol";
import "./interfaces/IWorkerManager.sol";

/**
 * @title WorkerManager
 * @dev Manages worker registrations, stake handling
 * @notice This contract allows workers to register, stake, and be allocated to batches of work.
 */
contract WorkerManager is IWorkerManager, FuelRetriever, Ownable, Pausable {

    // Constants : DEBUG only
    bool public STAKING_REQUIREMENT_TOGGLE_ENABLED = false;

    // ------ Worker State Structure : 2 slots
    struct WorkerState {
        uint128 allocated_quality_work_batch;
        uint128 allocated_relevance_work_batch;
        uint64 last_interaction_date;
        uint16 succeeding_novote_count;
        bool currently_working;
        bool registered;
        bool unregistration_request;
        bool isWorkerSeen;
        uint64 registration_date;
        uint64 allocated_batch_counter;
        uint64 majority_counter;
        uint64 minority_counter;
    }

    // ------ Worker Status Structure : 2 slots
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

    mapping(address => WorkerState) public WorkersState;
    mapping(address => WorkerStatus) public WorkersStatus;

    // ------ Worker & Stake related structure
    mapping(address => uint256) public SystemStakedTokenBalance; // maps user's address to voteToken balance

    // ------ Worker management structures
    address[] public availableWorkers;
    address[] public busyWorkers;
    address[] public toUnregisterWorkers;
    address[] public AllWorkersList;

    uint16 constant MIN_REGISTRATION_DURATION = 120; // in seconds
    uint32 private REMOVED_WORKER_INDEX_VALUE = 2 ** 32 - 1;

    // ------ Contract allowed to interact with this contract
    mapping(address => bool) public allowedContract;

    // Worker registration events    
    /**
     * @notice Emitted when a worker registers.
     * @param worker The address of the worker that registered.
     * @param timestamp The timestamp of the registration.
     */
    event _WorkerRegistered(address indexed worker, uint256 timestamp);

    /**
     * @notice Emitted when a worker unregisters.
     * @param worker The address of the worker that unregistered.
     * @param timestamp The timestamp of the unregistration.
     */
    event _WorkerUnregistered(address indexed worker, uint256 timestamp);

    /**
     * @notice Emitted when stake is allocated for a worker
     */
    event _StakeAllocated(uint256 numTokens, address indexed voter);

    /**
     * @notice Emitted when work is allocated to a worker
     * @param batchID The ID of the batch of work.
     * @param worker The address of the worker allocated to the batch.
     */
    event WorkAllocated(uint128 indexed batchID, address worker);

    /**
     * @notice Emitted when Parameters Manager is updated
     * @param parameters address of the new Parameters Manager
     */
    event ParametersUpdated(address parameters);

    /**
     * @notice Constructor
     * @param _parametersManager address of the Parameter Contract
     */
    constructor(address _parametersManager)
    FuelRetriever(_parametersManager) {
        require(_parametersManager != address(0), "Parameters Manager address cannot be zero.");
        Parameters = IParametersManager(_parametersManager);
    }

    /**
    * @notice Allows a contract to interact with this WorkerManager.
    * @param _contract The address of the contract to allow.
    */
    function allowContract(address _contract) external onlyOwner {
        require(_contract != address(0), "Contract address cannot be zero.");
        allowedContract[_contract] = true;
    }

    /**
     * @notice Removes a contract from the list of allowed contracts that can interact with this contract.
     * @param _contract The address of the contract to disallow.
     */
    function disallowContract(address _contract) external onlyOwner {
        require(_contract != address(0), "Contract address cannot be zero.");
        allowedContract[_contract] = false;
    }

    /**
    * @dev Ensures that the function can only be called by allowed contracts.
    */
    modifier _onlyAllowedContract() {
        require(allowedContract[msg.sender], "Caller is not allowed to interact with this contract");
        _;
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

    /**
     * @notice Registers the sender as a worker, enabling them to receive work allocations.
     * @notice Requires the sender to meet stake requirements and not be currently registered or kicked due to inactivity.
     */
    function RegisterWorker() external {
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
        _retrieveSFuel();
        emit _WorkerRegistered(msg.sender, block.timestamp);
    }

    /**
     * @notice Unregisters the sender, removing them from receiving future work allocations.
     * @notice Handles unregistration requests immediately if not currently working, or flags the worker for later unregistration.
     */
    function UnregisterWorker() external {
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
        _retrieveSFuel();
    }

    /**
     * @notice Checks if the worker can currently register.
     * @param worker_state The state of the worker to check.
     * @return bool True if the worker can register, false otherwise.
     */
    function canWorkerRegister(WorkerState storage worker_state)
    internal
    view
    returns(bool) {
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

    /**
     * @notice Requests allocation of stake for a worker to meet the staking requirements.
     * @param _numTokens The number of tokens to allocate as stake.
     * @param user_ The address of the worker requesting stake allocation.
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

        SystemStakedTokenBalance[user_] += _numTokens;
        emit _StakeAllocated(_numTokens, user_);
    }

    /**
     * @notice Handles the internal logic required for staking when a worker registers.
     * @param worker The address of the worker to handle staking for.
     */
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

    /**
     * @notice Updates the state of a worker upon registration.
     * @param worker The address of the worker being registered.
     * @param worker_state The current state of the worker to update.
     */
    function updateWorkerStateOnRegistration(
        address worker,
        WorkerState storage worker_state
    ) internal {
        // Update worker state on successful registration
        if (!worker_state.isWorkerSeen) {
            AllWorkersList.push(worker);
            worker_state.isWorkerSeen = true;
        }
        worker_state.registered = true;
        worker_state.unregistration_request = false;
        worker_state.registration_date = uint64(block.timestamp);
        worker_state.succeeding_novote_count = 0;
    }

    /**
     * @notice Updates the state of a worker upon unregistration.
     * @param worker The address of the worker being unregistered.
     * @param worker_state The current state of the worker to update.
     */
    function updateWorkerStateOnUnregistration(
        address worker,
        WorkerState storage worker_state
    ) internal {
        worker_state.last_interaction_date = uint64(block.timestamp);
        WorkersStatus[worker].isToUnregisterWorker = false;
        worker_state.registered = false;
    }

    /**
     * @notice Internal function to process the logic of unregistration request by a worker.
     * @param worker The address of the worker requesting unregistration.
     * @param worker_state The current state of the worker.
     */
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

    /**
     * @notice Requests unregistration for a worker, flagging them for later unregistration if currently working.
     * @param worker The address of the worker requesting unregistration.
     * @param worker_state The current state of the worker.
     */
    function requestUnregistration(
        address worker,
        WorkerState storage worker_state
    ) internal {
        worker_state.unregistration_request = true;
        toUnregisterWorkers.push(worker);
        WorkersStatus[worker].isToUnregisterWorker = true;
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
        }
    }

    /**
     * @notice Pop worker from the Logoff workers
     */
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
        }
    }

    /**
     * @notice Push worker in the Available workers (internal)
     * @param _worker worker address
     */
    function PushInAvailableWorkers(address _worker) internal {
        require(
            _worker != address(0),
            "Error: Can't push the null address in available workers"
        );
        if (!isInAvailableWorkers(_worker)) {
            availableWorkers.push(_worker);

            // Update Worker State
            WorkersStatus[_worker].isActiveWorker = true;
            WorkersStatus[_worker].availableWorkersIndex = uint32(
                availableWorkers.length - 1
            );
            // we can cast safely because availableWorkers.length << 2**32
        }
    }

    /* 
      @notice Push worker in the Busy workers (internal)
    * @param _worker worker address
    */
    function PushInBusyWorkers(address _worker) internal {
        require(
            _worker != address(0),
            "Error: Can't push the null address in busy workers"
        );
        if (!isInBusyWorkers(_worker)) {
            busyWorkers.push(_worker);

            // Update Worker State
            WorkersStatus[_worker].isBusyWorker = true;
            WorkersStatus[_worker].busyWorkersIndex = uint32(
                busyWorkers.length - 1
            );
        }
    }

    /*
     * Swap worker from Available to Busy workers, only allowed by the contract itself
     * @param _worker worker address
     */
    function SwapFromAvailableToBusyWorkers(address _worker) external _onlyAllowedContract() {

        require(
            isInAvailableWorkers(_worker),
            "Worker must be in Available workers"
        );
        PopFromAvailableWorkers(_worker);
        PushInBusyWorkers(_worker);
    }

    /*
     * Swap worker from Busy to Available workers
     * @param _worker worker address
     */
    function SwapFromBusyToAvailableWorkers(address _worker) external _onlyAllowedContract() {
        PopFromBusyWorkers(_worker);
        PushInAvailableWorkers(_worker);
    }

    /*
     * Remove from both Available and Busy workers
     * @param _worker worker address
     */
    function RemoveFromAvailableAndBusyWorkers(address _worker) external _onlyAllowedContract() {
        PopFromAvailableWorkers(_worker);
        PopFromBusyWorkers(_worker);
    }

    /* 
        @notice Push worker in the Logoff workers (internal)
        * @param _worker worker address
    */
    function processLogoffRequests(uint256 n_iteration) external _onlyAllowedContract() {
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
            }
        }
        if (toUnregisterWorkers.length == 0) {
            delete toUnregisterWorkers;
        }
    }

    /* 
     * @notice Select Address for User
     * @param _worker worker address
     * @param _TokensAmountToAllocate amount of tokens to allocate
     */
    function SelectAddressForUser(
        address _worker,
        uint256 _TokensAmountToAllocate
    ) public view returns(address) {
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

        for (uint256 i = 0; i <= 3; i++) {
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

    ///////////////////////////////////////////////////////////////////////////// 
    ///////////////////////////////// GETTERS ///////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Retrieves the state of a specified worker.
     * @notice Returns the WorkerState struct containing information about the worker's current status, batches, and more.
     * @param worker The address of the worker whose state is being queried.
     * @return WorkerState A struct containing the worker's current state.
     */
    function getWorkerState(address worker)
    public
    view
    returns(WorkerState memory) {
        return WorkersState[worker];
    }

    /**
     * @notice Retrieves the status of a specified worker.
     * @notice Returns the WorkerStatus struct containing flags representing the worker's activity and availability.
     * @param worker The address of the worker whose status is being queried.
     * @return WorkerStatus A struct containing the worker's current status.
     */
    function getWorkerStatus(address worker)
    public
    view
    returns(WorkerStatus memory) {
        return WorkersStatus[worker];
    }

    /**
     * @notice Gets the list of all workers currently available for work.
     * @notice Returns an array of addresses of workers that are not currently allocated to any batch.
     * @return address[] An array of addresses of available workers.
     */
    function getAvailableWorkers() public view returns(address[] memory) {
        return availableWorkers;
    }

    /**
     * @notice Gets the list of all workers currently busy with work.
     * @notice Returns an array of addresses of workers that are currently allocated to a batch.
     * @return address[] An array of addresses of busy workers.
     */
    function getBusyWorkers() public view returns(address[] memory) {
        return busyWorkers;
    }

    /**
     * @notice Gets the list of all workers that have requested to unregister.
     * @notice Returns an array of addresses of workers that are in the process of unregistration.
     * @return address[] An array of addresses of workers requesting to unregister.
     */
    function getToUnregisterWorkers() public view returns(address[] memory) {
        return toUnregisterWorkers;
    }

    /**
     * @notice Checks if a worker is allocated to a specific batch for a task.
     * @param _DataBatchId The ID of the data batch.
     * @param _worker The address of the worker.
     * @param _task The type of task (Quality or Relevance).
     * @return bool True if the worker is allocated to the batch for the task, false otherwise.
     */
    function isWorkerAllocatedToBatch(uint128 _DataBatchId, address _worker, TaskType _task) external view returns(bool) {
        WorkerState storage worker_state = WorkersState[_worker];
        if (_task == TaskType.Quality) {
            return worker_state.allocated_quality_work_batch == _DataBatchId;
        } else {
            return worker_state.allocated_relevance_work_batch == _DataBatchId;
        }
    }

    /**
     * @notice Checks if a specific address is currently registered as a worker.
     * @param worker The address to check.
     * @return bool True if the address is registered as a worker, false otherwise.
     */
    function isWorkerRegistered(address worker) external view returns(bool) {
        WorkerState storage worker_state = WorkersState[worker];
        return worker_state.registered;
    }

    /**
     * @notice Determines if a worker should request unregistration based on their current working status.
     * @param worker_state The state of the worker to check.
     * @return bool True if the worker should request unregistration, false otherwise.
     */
    function shouldRequestUnregistration(WorkerState storage worker_state)
    internal
    view
    returns(bool) {
        return
        worker_state.currently_working == true &&
            !worker_state.unregistration_request &&
            !IsInLogoffList(msg.sender);
    }

    /** 
     * @notice Checks if Worker can Unregister
     * @param worker_state worker state
     */
    function canWorkerUnregister(WorkerState storage worker_state)
    internal
    view
    returns(bool) {
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

    /**
     * @notice Checks if Worker is Available
     * @param _worker worker address
     */
    function isInAvailableWorkers(address _worker) public view returns(bool) {
        return WorkersStatus[_worker].isActiveWorker;
    }

    /**
     * @notice Checks if Worker is Busy
     * @param _worker worker address
     */
    function isInBusyWorkers(address _worker) public view returns(bool) {
        return WorkersStatus[_worker].isBusyWorker;
    }

    /**
     * @notice Checks if Worker in the "to log off" list
     * @param _worker worker address
     */
    function IsInLogoffList(address _worker) public view returns(bool) {
        return WorkersStatus[_worker].isToUnregisterWorker;
    }

    /**
     * @notice Checks if Worker is Kicked
     * @param user_ worker address
     */
    function IsAddressKicked(address user_) public view returns(bool status) {
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

    /**
     * @notice Checks if Worker (address calling this) is Kicked
     */
    function AmIKicked() public view returns(bool status) {
        return IsAddressKicked(msg.sender);
    }

    /////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// ADMIN DELETION ////////////////////////////
    /////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Destroy AllWorkersArray, important to release storage space if critical
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
    }

    /**
     * @notice Destroy WorkersStatus for users_ array, important to release storage space if critical
     */
    function deleteManyWorkersAtIndex(uint256[] memory indices_)
    public
    onlyOwner {
        for (uint256 i = 0; i < indices_.length; i++) {
            uint256 _index = indices_[i];
            deleteWorkersAtIndex(_index);
        }
    }

    /**
     * @notice Destroy WorkersStatus, important to release storage space if critical
     */
    function deleteWorkersStatus(address user_) public onlyOwner {
        delete WorkersStatus[user_];
    }

    /**
     * @notice Destroy WorkersStatus for users_ array, important to release storage space if critical
     */
    function deleteManyWorkersStatus(address[] memory users_) public onlyOwner {
        for (uint256 i = 0; i < users_.length; i++) {
            address _user = users_[i];
            deleteWorkersStatus(_user);
        }
    }

    /**
     * @notice Destroy WorkersState, important to release storage space if critical
     */
    function deleteWorkersState(address user_) public onlyOwner {
        delete WorkersState[user_];
        delete SystemStakedTokenBalance[user_];
    }

    /**
     * @notice Destroy WorkersStatus for users_ array, important to release storage space if critical
     */
    function deleteManyWorkersState(address[] memory users_) public onlyOwner {
        for (uint256 i = 0; i < users_.length; i++) {
            address _user = users_[i];
            deleteWorkersState(_user);
        }
    }

}