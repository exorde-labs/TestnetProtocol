// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAddressManager {
    function isMasterOf(address _master, address _address) external returns(bool);

    function isSubWorkerOf(address _master, address _address) external returns(bool);

    function AreMasterSubLinked(address _master, address _address) external returns(bool);

    function getMasterSubs(address _master) external view returns(address);

    function getMaster(address _worker) external view returns(address);

    function FetchHighestMaster(address _worker) external view returns(address);
}


contract AddressMasterReader is Ownable {
    IAddressManager public AddressManager;

    constructor(address AddressManager_){
        AddressManager = IAddressManager(AddressManager_);
    }

    function getManyMasters(address[] calldata addresses_)
        public
        view
        returns (address[] memory)
    {
        address[] memory masters = new address[](addresses_.length);
        for (uint128 i = 0; i < addresses_.length; i++) {
            masters[i] = AddressManager.FetchHighestMaster(addresses_[i]);
        }
        return masters;
    }

}