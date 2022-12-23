// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAddressManager {
    function getMaster(address _worker) external view returns (address);
    function FetchHighestMaster(address _worker) external view returns (address);
}


contract MasterReader is Ownable {

    function getManyMaster(address contract_, address[] memory users)
        public
        view
        returns (address[] memory)
    {
        IAddressManager AddressManager = IAddressManager(contract_);
        address[] memory address_list = new address[](users.length);
        for (uint256 i = 0; i < address_list.length; i++) {
            address_list[i] = AddressManager.getMaster(users[i]);
        }
        return address_list;
    }

    function getMaster(address contract_, address user)
        public
        view
        returns (address)
    {
        IAddressManager AddressManager = IAddressManager(contract_);
        return AddressManager.getMaster(user);
    }

    function getManyHighestMaster(address contract_, address[] memory users)
        public
        view
        returns (address[] memory)
    {
        IAddressManager AddressManager = IAddressManager(contract_);
        address[] memory address_list = new address[](users.length);
        for (uint256 i = 0; i < address_list.length; i++) {
            address_list[i] = AddressManager.FetchHighestMaster(users[i]);
        }
        return address_list;
    }
}