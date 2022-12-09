// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IReputation {
    function balanceOf(address _owner) external view returns (uint256 balance);
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

    function ProxyTransferRewards(address _user, address _recipient) external returns (bool);

    function RewardsBalanceOf(address _address) external returns (uint256);
}

interface IParametersManager {
    // -------------- GETTERS : ADDRESSES --------------------
    function getStakeManager() external view returns (address);

    function getRepManager() external view returns (address);

    function getReputationSystem() external view returns (address);

    function getAddressManager() external view returns (address);

    function getRewardManager() external view returns (address);

    function getArchivingSystem() external view returns (address);

    function getSpottingSystem() external view returns (address);

    function getComplianceSystem() external view returns (address);

    function getIndexingSystem() external view returns (address);

    function getsFuelSystem() external view returns (address);

    function getExordeToken() external view returns (address);

    function get_MAX_UPDATE_ITERATIONS() external view returns (uint256);
}

contract AddressManager is Ownable {
    mapping(address => mapping(address => bool)) public MasterClaimingWorker; // master -> worker -> true/false

    mapping(address => address[]) public MasterToSubsMap; // master -> workers dynamic array, 1->N relation
    mapping(address => address) public SubToMasterMap; 
    // worker -> master, only 1 master per worker address, 1->1 relation
    // ALWAYS [MASTER, WORKER] order in the arguments of all functions

    uint256 MAX_MASTER_LOOKUP = 5;

    IParametersManager public Parameters;
    // ------------------------------------------------------------------------------------------

    event ParametersUpdated(address parameters);
    event AddressAddedByMaster(address indexed account, address account2);
    event AddressRemovedByMaster(address indexed account, address account2);
    event AddressAddedByWorker(address indexed account, address account2);
    event AddressRemovedByWorker(address indexed account, address account2);
    event ReputationTransfered(address indexed account, address account2);
    event RewardsTransfered(address indexed account, address account2);

    // ------------------------------------------------------------------------------------------

    /**
     * @notice Updates the Parameters Manager contract to use
     * @param addr new address of the Parameters Manager contract
     */
    function updateParametersManager(address addr) public onlyOwner {
        require(addr != address(0));
        Parameters = IParametersManager(addr);
        emit ParametersUpdated(addr);
    }

    /**
     * @dev Destroy Contract, important to release storage space if critical
     */
    function destroyContract() public onlyOwner {
        selfdestruct(payable(owner()));
    }
    //// --------------------------- GETTERS FOR MASTERS

    /**
     * @notice Returns if _master is a master of msg.sender
     * @param _master address
     * @return bool true if _master is a Master of msg.sender
     */
    function isMasterOfMe(address _master) public view returns (bool) {
        return MasterClaimingWorker[_master][msg.sender];
    }

    /**
     * @notice Returns if _master is a master of _address
     * @param _master address
     * @param _address address
     * @return bool true if _master is a Master of _address
     */
    function isMasterOf(address _master, address _address) public view returns (bool) {
        return MasterClaimingWorker[_master][_address];
    }

    /**
     * @notice Get all sub workers for a given Master address
     * @param _master address
     * @return array of addresses
     */
    function getMasterSubs(address _master) public view returns (address[] memory) {
        return MasterToSubsMap[_master];
    }

    //// --------------------------- GETTERS FOR WORKERS

    /**
     * @notice Check if a worker is a sub address of the msg.sender
     * @param _worker worker address
     * @return bool true if _worker is a wub worker of msg.sender (master)
     */
    function isSubWorkerOfMe(address _worker) public view returns (bool) {
        return MasterClaimingWorker[msg.sender][_worker];
    }

    /**
     * @notice Returns the master claimed by worker _worker
     * @param _master address
     * @param _address address
     * @return bool true if _address is claimed by _master
     */
    function isSubWorkerOf(address _master, address _address) public view returns (bool) {
        return MasterClaimingWorker[_master][_address];
    }

    /**
     * @notice Check if sub worker is in the MasterToSubsMap mapping of Master
     * @param _worker address
     * @param _master address
     * @param iterations_max max iteration count
     * @param starting_index starting index of the loop
     * @return bool true if _address is in the MasterToSubsMap mapping of _master
     */
    function isSubInMasterArray(address _worker, address _master, uint256 iterations_max, uint256 starting_index) 
    public view returns (bool) {
        bool found = false;
        uint256 k = 0;
        address[] memory sub_workers_ = MasterToSubsMap[_master];
        require(starting_index <=  sub_workers_.length, "starting_index must not be out of bounds");
        for (uint256 i = starting_index; i < sub_workers_.length; i++) {
            if (sub_workers_[i] == _worker) {
                found = true;
                break;
            }
            k += 1;
            if ( k >= iterations_max ){
                break;
            }
        }
        return found;
    }

    /**
     * @notice Returns the master claimed by worker _worker
     * @param _worker address
     * @return address of worker's master address
     */
    function getMaster(address _worker) public view returns (address) {
        return SubToMasterMap[_worker];
    }

    /**
     * @notice Pops _worker from Master's MasterToSubsMap array
     * @param _master address
     * @param _worker address
     * @param iterations_max max number of iterations
     * @param starting_index start index to loop
     */
    function PopFromSubsArray(address _master, address _worker, uint256 iterations_max, uint256 starting_index) 
    internal {
        require(starting_index <=  MasterToSubsMap[_master].length, "starting_index must not be out of bounds");
        uint256 index = 0;
        bool found = false;
        uint256 k = 0;
        for (uint256 i = starting_index; i < MasterToSubsMap[_master].length; i++) {
            if (MasterToSubsMap[_master][i] == _worker) {
                found = true;
                index = i;
                break;
            }
            k += 1;
            if ( k >= iterations_max ){
                break;
            }
        }
        // require(found, "not found when PopFromBusyWorkers");
        if (found) {
            MasterToSubsMap[_master][index] = MasterToSubsMap[_master][MasterToSubsMap[_master].length - 1];
            MasterToSubsMap[_master].pop();
        }
    }

    //// --------------------------- // verify bidirectional link
    /**
     * @notice Checks if a _master and _address and mapped in both ways (master & sub worker of)
     * @param _master address
     * @param _address address
     * @return bool true if both addresses are mapped to each other
     */
    function AreMasterWorkerLinked(address _master, address _address) public view returns (bool) {
        return (isSubWorkerOf(_master, _address) && (getMaster(_address) == _master) );
    }

    //// -----------------------------------------------------------
    //// -------------------- MASTER FUNCTIONS ---------------------
    //// -------- ADD

    /**
     * @notice Add sub-worker addresses mapped to msg.sender
     * @param _address address
     */
    function MasterClaimSub(address _address) public {
        require(_address != address(0), "_address must be non zero");
        MasterClaimingWorker[msg.sender][_address] = true;
        MasterToSubsMap[msg.sender].push(_address);
        emit AddressAddedByMaster(msg.sender, _address);
    }

    /**
     * @notice Add mutliple sub-worker addresses to be mapped to msg.sender
     * @param _addresses array of address
     * @param iterations_max max number of iterations
     * @param starting_index start index to loop
     */
    function MasterClaimManySubs(address[] memory _addresses, uint256 iterations_max, uint256 starting_index) public {
        require(starting_index <=  _addresses.length, "starting_index must not be out of bounds");
        uint256 k = 0;
        for (uint256 i = starting_index; i < _addresses.length; i++) {
            require(_addresses[i] != address(0), "addresses in array must be non zero");
            if (MasterClaimingWorker[msg.sender][_addresses[i]] != true) {
                MasterClaimingWorker[msg.sender][_addresses[i]] = true;
                MasterToSubsMap[msg.sender].push(_addresses[i]);
                emit AddressAddedByMaster(msg.sender, _addresses[i]);
            }
            k += 1;
            if ( k >= iterations_max ){
                break;
            }
        }
    }

    //// -------- REMOVE

    /**
     * @notice Remove sub-worker addresses mapped to msg.sender
     * @param _address address
     * @param start_index optional, let to zero if the number of subs is low
     */
    function MasterRemoveSub(address _address, uint256 start_index) public {
        require(
            MasterClaimingWorker[msg.sender][_address] != false,
            "Can't remove: Master not claiming this Sub Address"
        );
        MasterClaimingWorker[msg.sender][_address] = false;
        PopFromSubsArray(msg.sender, _address, Parameters.get_MAX_UPDATE_ITERATIONS(), start_index);
        emit AddressRemovedByMaster(msg.sender, _address);
    }

    /**
     * @notice Remove Multiple sub-worker addresses mapped to msg.sender
     * @param _addresses array of addresses
     */
    function MasterRemoveManySubs(address[] memory _addresses, uint256 iterations_max, uint256 start_index) public {
        uint256 k = 0;
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (MasterClaimingWorker[msg.sender][_addresses[i]] != false) {
                MasterClaimingWorker[msg.sender][_addresses[i]] = false;
                PopFromSubsArray(msg.sender, _addresses[i], iterations_max, start_index);
                emit AddressRemovedByMaster(msg.sender, _addresses[i]);
            }
            k += 1;
            if ( k >= iterations_max ){
                break;
            }
        }
    }

    //// -----------------------------------------------------------
    //// -------------------- WORKER FUNCTIONS ---------------------

    /**
     * @notice Fetch the Highest Master on the graph starting from the _worker leaf
               This function will return the worker address itself, if master has not been set.
               This behavior might be subject to change later.
     * @param _worker address
     * @return The highest master of worker _worker, or _worker if no master found
     */
    function FetchHighestMaster(address _worker) public view returns (address) {
        require(_worker != address(0), "FetchHighestMaster: input _worker needs to be non null address");
        address _master = SubToMasterMap[_worker];
        address _highest_master = _worker;
        uint256 iterations = MAX_MASTER_LOOKUP;

        while (_master != address(0) && (iterations > 0)) {
            _highest_master = _master;
            _master = SubToMasterMap[_master];
            iterations -= 1;
        }
        return (_highest_master);
    }

    /**
     * @notice Transfer Current Reputation (REP) of address _worker to its master
     * @param _worker address
     */
    function TransferRepToMaster(address _worker) internal {
        require(Parameters.getRepManager() != address(0), "RepManager is null in Parameters");
        require(Parameters.getReputationSystem() != address(0), "RepManager is null in Parameters");
        IRepManager _RepManager = IRepManager(Parameters.getRepManager());
        IReputation _Reputation = IReputation(Parameters.getReputationSystem());
        require(
            SubToMasterMap[_worker] != address(0),
            "TransferRepToMaster: input _worker needs to have a non-null master"
        ); // needs non null address to transfer Rep.
        uint256 _worker_rep = _Reputation.balanceOf(_worker);
        address _highest_master = FetchHighestMaster(_worker);
        if (_worker_rep > 0) {
            // mint current worker rep to the highest master
            require(
                _RepManager.mintReputationForWork(_worker_rep, _highest_master, ""),
                "TransferRepToMaster: could not mint Rep to master"
            );
            // then burn the current worker rep to perform the "transfer"
            require(
                _RepManager.burnReputationForWork(_worker_rep, _worker, ""),
                "TransferRepToMaster: could not burn Rep from worker"
            );
            emit ReputationTransfered(_worker, _highest_master);
        }
    }

    /**
     * @notice Transfer Current Rewards of address _worker to its master
     * @param _worker address
     */
    function TransferRewardsToMaster(address _worker) internal {
        require(Parameters.getRewardManager() != address(0), "RewardManager is null in Parameters");
        IRewardManager _RewardManager = IRewardManager(Parameters.getRewardManager());
        require(address(_RewardManager) != address(0), "RewardManager needs to be setup");
        require(
            SubToMasterMap[_worker] != address(0),
            "TransferRepToMaster: input _worker needs to have a non-null master"
        ); // needs non null address to transfer Rep.
        uint256 _worker_rewards = _RewardManager.RewardsBalanceOf(_worker);
        address _highest_master = FetchHighestMaster(_worker);
        if (_worker_rewards > 0) {
            require(
                _RewardManager.ProxyTransferRewards(_worker, _highest_master),
                "TransferRewardsToMaster: could not transfer rewards"
            );
            emit RewardsTransfered(_worker, _highest_master);
        }
    }

    /**
     * @notice Claim _master Address as master of msg.sender
     * @param _master address
     */
    function ClaimMaster(address _master) public {
        require(_master != address(0)," _master must be non null");
        SubToMasterMap[msg.sender] = _master; //overwrite, 1->1 link, Sub to Master
        TransferRepToMaster(msg.sender);
        TransferRewardsToMaster(msg.sender);
        emit AddressAddedByWorker(msg.sender, _master);
    }

    /**
     * @notice Unclaim _master Address as master of msg.sender
     * @param _master address
     */
    function RemoveMaster(address _master) public {
        SubToMasterMap[msg.sender] = address(0); //reset to adress 0x0000000..0
        emit AddressRemovedByWorker(msg.sender, _master);
    }
}