// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IReputationSystem {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function balanceOfAt(address _owner, uint256 _blockNumber) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}


contract ReputationReader is Ownable {

    IReputationSystem Reputation;

    constructor(address Reputation_){
        Reputation = IReputationSystem(Reputation_);
    }

    function getManyReputations(address[] memory users)
        public
        view
        returns (uint256[] memory)
    {
        uint256 _array_size = users.length;
        uint256[] memory rep_list = new uint256[](_array_size);
        for (uint256 i = 0; i <= _array_size; i++) {
            address user_ = users[i];
            rep_list[i] = Reputation.balanceOf(user_);
        }
        return rep_list;
    }

    function getManyReputationsAt(address[] memory users, uint256 _blockNumber)
        public
        view
        returns (uint256[] memory)
    {
        uint256 _array_size = users.length;
        uint256[] memory rep_list = new uint256[](_array_size);
        for (uint256 i = 0; i <= _array_size; i++) {
            address user_ = users[i];
            rep_list[i] = Reputation.balanceOfAt(user_, _blockNumber);
        }
        return rep_list;
    }
}