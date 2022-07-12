// SPDX-License-Identifier: GPL-3.0


pragma solidity >=0.5.0;




import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AddressManager{

    mapping (address =>  mapping (address => bool)) private WorkerSubAddresses;  // master -> worker -> true/false
    mapping (address =>  mapping (address => bool)) private WorkersClaims; // master -> worker -> true/false

    // ------------------------------------------------------------------------------------------

    event AddressAddedByMaster(address indexed account, bool isWhitelisted);
    event AddressRemovedByMaster(address indexed account, bool isWhitelisted);
    event AddressAddedByWorker(address indexed account, bool isWhitelisted);
    event AddressRemovedByWorker(address indexed account, bool isWhitelisted);


    //// --------------------------- MASTER FUNCTIONS


    function MasterClaimWorkerAddress(address _address)
        public
    {
        require(WorkerSubAddresses[msg.sender][_address] != true);
        WorkerSubAddresses[msg.sender][_address] = true;
        emit AddressAddedByMaster(_address, true);
    }

    function MasterRemoveAddress(address _address)
        public
    {        
        require(WorkerSubAddresses[msg.sender][_address] != false);
        WorkerSubAddresses[msg.sender][_address] = false;
        emit AddressRemovedByMaster(_address, false);        
    }


    //// --------------------------- WORKER FUNCTIONS

    function WorkerAddMasterAddress(address _address)
        public
    {
        require(WorkersClaims[_address][msg.sender] != true);
        WorkersClaims[_address][msg.sender] = true;
        emit AddressAddedByWorker(_address, true);
    }

    function WorkerRemoveMasterAddress(address _address)
        public
    {        
        require(WorkersClaims[_address][msg.sender] != false);
        WorkersClaims[_address][msg.sender] = false;
        emit AddressRemovedByWorker(_address, false);        
    }


    //// --------------------------- GETTERS FOR MASTERS
    
        function isSMasterClaimingMe(address _address)
        public
        view
        returns (bool)
    {   
        return WorkerSubAddresses[msg.sender][_address];
    }


    function isMasterClaimingWorker(address _master, address _address)
        public
        view
        returns (bool)
    {   
        return WorkerSubAddresses[_master][_address];
    }

    //// --------------------------- GETTERS FOR WORKERS


    function isWorkerClaimingMe(address _worker)
        public
        view
        returns (bool)
    {   
        return WorkersClaims[msg.sender][_worker];
    }

    function isWorkerClaimingMaster(address _master, address _address)
        public
        view
        returns (bool)
    {   
        return WorkersClaims[_master][_address];
    }

    //// ---------------------------

    
    function AreMasterWorkerLinked(address _master, address _worker)
        public
        view
        returns (bool)
    {   
        return (isWorkerClaimingMaster(_master, _worker) && isMasterClaimingWorker(_master, _worker));
    }

    
}