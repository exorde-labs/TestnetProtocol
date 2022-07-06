// SPDX-License-Identifier: GPL-3.0


pragma solidity >=0.5.0;




import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AddressManager{

    mapping (address =>  mapping (address => bool)) private WorkerSubAddresses; 

    // ------------------------------------------------------------------------------------------

    event AddressAdded(address indexed account, bool isWhitelisted);
    event AddressRemoved(address indexed account, bool isWhitelisted);

    function isSenderMasterOf(address _address)
        public
        view
        returns (bool)
    {   
        return WorkerSubAddresses[msg.sender][_address];
    }

    function isSenderSubOf(address _master)
        public
        view
        returns (bool)
    {   
        return WorkerSubAddresses[_master][msg.sender];
    }

    function isSubAddress(address _master, address _address)
        public
        view
        returns (bool)
    {   
        return WorkerSubAddresses[_master][_address];
    }

    function addAddress(address _address)
        public
    {
        require(WorkerSubAddresses[msg.sender][_address] != true);
        WorkerSubAddresses[msg.sender][_address] = true;
        emit AddressAdded(_address, true);
    }

    function removeAddress(address _address)
        public
    {        
        require(WorkerSubAddresses[msg.sender][_address] != false);
        WorkerSubAddresses[msg.sender][_address] = false;
        emit AddressRemoved(_address, false);        
    }


    
}