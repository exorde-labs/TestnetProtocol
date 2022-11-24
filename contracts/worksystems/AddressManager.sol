// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
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
}

contract AddressManager is Ownable {
    mapping(address => mapping(address => bool)) public MasterClaimingWorker; // master -> worker -> true/false
    mapping(address => mapping(address => bool)) public WorkerClaimingMaster; // master -> worker -> true/false

    mapping(address => address[]) public MasterToSubsMap; // master -> workers dynamic array, 1->N relation
    mapping(address => address) public SubToMasterMap; // worker -> master, only 1 master per worker address, 1->1 relation
    // ALWAYS [MASTER, WORKER] order in the arguments of all functions

    uint256 MAX_MASTER_LOOKUP = 5;

    IParametersManager public Parameters;
    // ------------------------------------------------------------------------------------------

    event AddressAddedByMaster(address indexed account, address account2);
    event AddressRemovedByMaster(address indexed account, address account2);
    event AddressAddedByWorker(address indexed account, address account2);
    event AddressRemovedByWorker(address indexed account, address account2);
    event ReputationTransfered(address indexed account, address account2);
    event RewardsTransfered(address indexed account, address account2);

    // ------------------------------------------------------------------------------------------

    function updateParametersManager(address addr) public onlyOwner {
        require(addr != address(0));
        Parameters = IParametersManager(addr);
    }

    //// --------------------------- GETTERS FOR MASTERS

    function isMasterOfMe(address _master) public view returns (bool) {
        return MasterClaimingWorker[_master][msg.sender];
    }

    function isMasterOf(address _master, address _address) public view returns (bool) {
        return MasterClaimingWorker[_master][_address];
    }

    function getMasterSubs(address _master) public view returns (address[] memory) {
        return MasterToSubsMap[_master];
    }

    //// --------------------------- GETTERS FOR WORKERS

    function isSubWorkerOfMe(address _worker) public view returns (bool) {
        return MasterClaimingWorker[msg.sender][_worker];
    }

    function isSubWorkerOf(address _master, address _address) public view returns (bool) {
        return MasterClaimingWorker[_master][_address];
    }

    function isSubInMasterArray(address _worker, address _master) public view returns (bool) {
        bool found = false;
        address[] memory sub_workers_ = MasterToSubsMap[_master];
        for (uint256 i = 0; i < sub_workers_.length; i++) {
            if (sub_workers_[i] == _worker) {
                found = true;
                break;
            }
        }
        return found;
    }

    function getMaster(address _worker) public view returns (address) {
        return SubToMasterMap[_worker];
    }

    function PopFromSubsArray(address _master, address _worker) internal {
        uint256 index = 0;
        bool found = false;
        for (uint256 i = 0; i < MasterToSubsMap[_master].length; i++) {
            if (MasterToSubsMap[_master][i] == _worker) {
                found = true;
                index = i;
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
    function AreMasterSubLinked(address _master, address _address) public view returns (bool) {
        return (isSubWorkerOf(_master, _address) && isMasterOf(_master, _address));
    }

    //// -----------------------------------------------------------
    //// -------------------- MASTER FUNCTIONS ---------------------
    //// -------- ADD

    function MasterClaimSub(address _address) public {
        MasterClaimingWorker[msg.sender][_address] = true;
        MasterToSubsMap[msg.sender].push(_address);
        emit AddressAddedByMaster(msg.sender, _address);
    }

    function MasterClaimManySubs(address[] memory _addresses) public {
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (MasterClaimingWorker[msg.sender][_addresses[i]] != true) {
                MasterClaimingWorker[msg.sender][_addresses[i]] = true;
                MasterToSubsMap[msg.sender].push(_addresses[i]);
                emit AddressAddedByMaster(msg.sender, _addresses[i]);
            }
        }
    }

    //// -------- REMOVE

    function MasterRemoveSub(address _address) public {
        require(
            MasterClaimingWorker[msg.sender][_address] != false,
            "Can't remove: Master not claiming this Sub Address"
        );
        MasterClaimingWorker[msg.sender][_address] = false;
        PopFromSubsArray(msg.sender, _address);
        emit AddressRemovedByMaster(msg.sender, _address);
    }

    function MasterRemoveManySubs(address[] memory _addresses) public {
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (MasterClaimingWorker[msg.sender][_addresses[i]] != false) {
                MasterClaimingWorker[msg.sender][_addresses[i]] = false;
                PopFromSubsArray(msg.sender, _addresses[i]);
                emit AddressRemovedByMaster(msg.sender, _addresses[i]);
            }
        }
    }

    //// -----------------------------------------------------------
    //// -------------------- WORKER FUNCTIONS ---------------------

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

    function ClaimMaster(address _master) public {
        WorkerClaimingMaster[_master][msg.sender] = true;
        SubToMasterMap[msg.sender] = _master; //overwrite, 1->1 link, Sub to Master
        TransferRepToMaster(msg.sender);
        TransferRewardsToMaster(msg.sender);
        emit AddressAddedByWorker(msg.sender, _master);
    }

    function RemoveMaster(address _master) public {
        require(WorkerClaimingMaster[_master][msg.sender] != false, "Can't remove Master: not claiming this address");
        WorkerClaimingMaster[_master][msg.sender] = false;
        SubToMasterMap[msg.sender] = address(0); //reset to adress 0x0000000..0
        emit AddressRemovedByWorker(msg.sender, _master);
    }
}
