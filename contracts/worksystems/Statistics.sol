// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Interface for the DataContract
interface IDataContract {
    function getTxCounter() external view returns (uint256);

    function getGlobalPeriodSpotCount() external view returns (uint256);

    function getLastBatchId() external view returns (uint256);

    function getLastCheckedBatchId() external view returns (uint256);

    function getLastAllocatedBatchId() external view returns (uint256);

    function getActiveWorkersCount() external view returns (uint256);

    function getAvailableWorkersCount() external view returns (uint256);

    function getBusyWorkersCount() external view returns (uint256);
}

// Statistics contract to monitor and maintain the DataContract
contract Statistics is Ownable {
    using SafeMath for uint256;

    uint256 public BaseTransactionCount = 0;

    // Constructor to set the initial base transaction count
    constructor(uint256 BaseTransactionCount_) {
        BaseTransactionCount = BaseTransactionCount_;
    }

    // Mappings and array to store monitored system addresses
    mapping(address => bool) private MonitoredSystemMap;
    address[] public MonitoredSystemAddress;
    mapping(address => uint256) private MonitoredSystemAddressIndex;

    // Events for monitoring and unmonitoring addresses
    event Monitored(address indexed account, bool isWhitelisted);
    event UnMonitored(address indexed account, bool isWhitelisted);

    // @notice check if an address is monitored
    function isMonitoredAddress(address _address) public view returns (bool) {
        return MonitoredSystemMap[_address];
    }

    // @notice update the base transaction count
    function updateBaseTransactionCount(uint256 BaseTransactionCountNew_) public onlyOwner {
        BaseTransactionCount = BaseTransactionCountNew_;
    }

    // @notice add a new address to the monitored system
    function addAddress(address _address) public onlyOwner {
        require(MonitoredSystemMap[_address] != true, "Address must not be whitelisted already");
        MonitoredSystemMap[_address] = true;
        MonitoredSystemAddress.push(_address);
        MonitoredSystemAddressIndex[_address] = MonitoredSystemAddress.length - 1;
        emit Monitored(_address, true);
    }

    // @notice remove an address from the monitored system
    function removeAddress(address _address) public onlyOwner {
        require(MonitoredSystemMap[_address] != false, "Address must be whitelisted already");
        MonitoredSystemMap[_address] = false;

        uint256 PrevIndex = MonitoredSystemAddressIndex[_address];
        MonitoredSystemAddressIndex[_address] = 999999999;

        MonitoredSystemAddress[PrevIndex] = MonitoredSystemAddress[MonitoredSystemAddress.length - 1]; // move last element
        MonitoredSystemAddressIndex[MonitoredSystemAddress[PrevIndex]] = PrevIndex;
        MonitoredSystemAddress.pop();

        emit UnMonitored(_address, false);
    }

    // @notice get the total transaction count from all monitored systems
    function TotalTxCount() public view returns (uint256) {
        uint256 _totalCount = BaseTransactionCount;
        for (uint256 i = 0; i < MonitoredSystemAddress.length; i++) {
            IDataContract dataContract = IDataContract(MonitoredSystemAddress[i]);
            _totalCount += dataContract.getTxCounter();
        }
        return _totalCount;
    }

    // @notice get the total active worker count from all monitored systems
    function TotalActiveWorkerCount() public view returns (uint256) {
        uint256 _totalCount = 0;
        for (uint256 i = 0; i < MonitoredSystemAddress.length; i++) {
            IDataContract dataContract = IDataContract(MonitoredSystemAddress[i]);
            _totalCount += dataContract.getActiveWorkersCount();
        }
        return _totalCount;
    }

    // @notice get the total available worker count from all monitored systems
    function TotalAvailableWorkerCount() public view returns (uint256) {
        uint256 _totalCount = 0;
        for (uint256 i = 0; i < MonitoredSystemAddress.length; i++) {
            IDataContract dataContract = IDataContract(MonitoredSystemAddress[i]);
            _totalCount += dataContract.getAvailableWorkersCount();
        }
        return _totalCount;
    }

    // @notice get the total busy worker count from all monitored systems
    function TotalBusyWorkerCount() public view returns (uint256) {
        uint256 _totalCount = 0;
        for (uint256 i = 0; i < MonitoredSystemAddress.length; i++) {
            IDataContract dataContract = IDataContract(MonitoredSystemAddress[i]);
            _totalCount += dataContract.getBusyWorkersCount();
        }
        return _totalCount;
    }
}
