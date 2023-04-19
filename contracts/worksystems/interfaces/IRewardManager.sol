// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

interface IRewardManager {
    function ProxyAddReward(uint256 _RewardsAllocation, address _user) external returns (bool);

    function ProxyTransferRewards(address _user, address _recipient) external returns (bool);

    function RewardsBalanceOf(address _address) external returns (uint256);
}
