// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

interface IAddressManager {
    function isMasterOf(address _master, address _address) external returns(bool);

    function isSubWorkerOf(address _master, address _address) external returns(bool);

    function AreMasterSubLinked(address _master, address _address) external returns(bool);

    function getMasterSubs(address _master) external view returns(address);

    function getMaster(address _worker) external view returns(address);

    function FetchHighestMaster(address _worker) external view returns(address);
}
