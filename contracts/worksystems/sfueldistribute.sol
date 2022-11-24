// SPDX-License-Identifier: APGL-3.0

/**
 *   SFuelContracts.sol - SChain Configuration
 *   Copyright (C) 2022-Present Lilius, Inc
 *   @author TheGreatAxios
 *
 *   SFuelContracts is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   SFuelContracts is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with SFuelContracts.  If not, see <https://www.gnu.org/licenses/>.
 *
 *   Huge Acknowledgment to AP & CS for Guidance on this contract
 */

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IEtherbase {
    receive() external payable;

    function retrieve(address payable receiver) external;

    function partiallyRetrieve(address payable receiver, uint256 amount) external;
}

///  SFuel Whitelisting Contract
///  TheGreatAxios
///  Allows S-Fuel to be guideded to the proper entities
///  Utilizes Etherbase Under the Hood for Native S-Fuel
contract SFuelContracts is Ownable {
    using SafeMath for uint256;

    //  The amount a user should have after being topped up
    uint256 private MIN_USER_BALANCE;

    //  Amount the contract should have after being filled up
    uint256 private MIN_CONTRACT_BALANCE;

    //  Allows contract to be paused in case of emergency
    bool public isPaused;

    mapping(address => bool) private Whitelist;
    /**
     *
     * Events
     *
     **/
    event EtherDeposit(address indexed sender, uint256 value);
    event ContractFilled(address indexed caller, uint256 value);
    event RetrievedSFuel(address indexed reciever, address indexed whitelistedContract, uint256 amount);
    event ReturnedSFuel(address indexed returner, address indexed whitelistedContract, uint256 amount);

    constructor() {
        MIN_USER_BALANCE = 0.001 ether;
        MIN_CONTRACT_BALANCE = 0.01 ether;
        isPaused = false;
    }

    function addAddress(address _address) public onlyOwner {
        require(Whitelist[_address] != true);
        Whitelist[_address] = true;
    }

    function removeAddress(address _address) public onlyOwner {
        require(Whitelist[_address] != false);
        Whitelist[_address] = false;
    }

    modifier isActive() {
        require(!isPaused, "Contract is Paused");
        _;
    }

    ///  Used by other contracts as a function to top up S-Fuel
    ///  msg.sender must be whitelisted to complete, onlyWhitelisted requires [msg.sender] to be contract
    ///  _retriever Address of User
    function retrieveSFuel(address payable _retriever) external payable isActive {
        require(Whitelist[msg.sender], "msg.sender contract needs to be whitelisted by Owner");
        if (getBalance(_retriever) < MIN_USER_BALANCE) {
            uint256 _retrievalAmount = MIN_USER_BALANCE.sub(getBalance(_retriever));
            require(getBalance(address(this)) >= _retrievalAmount, "Insufficent Balance in Contract");
            _retriever.transfer(_retrievalAmount);
            emit RetrievedSFuel(_retriever, msg.sender, _retrievalAmount);
        }
    }

    ///  Gets Etherbase Instance
    ///  IEtherbase -> Instance to interact with
    function _getEtherbase() internal pure returns (IEtherbase) {
        return IEtherbase(payable(0xd2bA3e0000000000000000000000000000000000));
    }

    ///  Retrieves S-Fuel Balance
    ///  _address ethereum address
    ///  uint256 balance
    function getBalance(address _address) public view returns (uint256) {
        return _address.balance;
    }

    receive() external payable {
        emit EtherDeposit(msg.sender, msg.value);
    }

    ///  Allows Depsoit of Ether
    fallback() external payable {
        if (msg.value > 0) {
            emit EtherDeposit(msg.sender, msg.value);
        }
    }

    ///  Allows CONTRACT_MANAGER to fill contract up
    ///  Must have ETHER_MANAGER_ROLE assigned on Etherbase
    function fillContract() external onlyOwner {
        uint256 _currentBalance = getBalance(address(this));
        uint256 _requestAmount = MIN_CONTRACT_BALANCE.sub(_currentBalance);
        _getEtherbase().partiallyRetrieve(payable(address(this)), _requestAmount);
        require(getBalance(address(this)) == MIN_CONTRACT_BALANCE, "Error Filling Up");
        emit ContractFilled(msg.sender, _requestAmount);
    }

    ///  Allows CONTRACT_MANAGER to Pause/Unpause Contract
    ///  Must Have CONTRACT_MANAGER_ROLE
    function TogglePause() external onlyOwner {
        isPaused = !isPaused;
    }
}
