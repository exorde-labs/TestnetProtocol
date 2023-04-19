// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

interface IStakeManager {
    function ProxyStakeAllocate(uint256 _StakeAllocation, address _stakeholder) external returns(bool);

    function ProxyStakeDeallocate(uint256 _StakeToDeallocate, address _stakeholder) external returns(bool);

    function AvailableStakedAmountOf(address _stakeholder) external view returns(uint256);

    function AllocatedStakedAmountOf(address _stakeholder) external view returns(uint256);
}
