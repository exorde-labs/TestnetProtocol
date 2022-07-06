pragma solidity ^0.5.4;

import "../controller/ControllerInterface.sol";

import "../controller/Avatar.sol";

import "./VotingMachineCallbacksInterface.sol";

import "./IntVoteInterface.sol";

contract DXDVotingMachineCallbacks is VotingMachineCallbacksInterface {
    IntVoteInterface public votingMachine;

    Avatar public avatar;

    modifier onlyVotingMachine() {
        require(msg.sender == address(votingMachine), "only VotingMachine");

        _;
    }

    // proposalId  ->  block number

    mapping(bytes32 => uint256) public proposalsBlockNumber;

    function mintReputation(
        uint256 _amount,
        address _beneficiary,
        bytes32 _proposalId
    ) external onlyVotingMachine returns (bool) {
        return ControllerInterface(avatar.owner()).mintReputation(_amount, _beneficiary, address(avatar));
    }

    function burnReputation(
        uint256 _amount,
        address _beneficiary,
        bytes32 _proposalId
    ) external onlyVotingMachine returns (bool) {
        return ControllerInterface(avatar.owner()).burnReputation(_amount, _beneficiary, address(avatar));
    }

    function stakingTokenTransfer(
        IERC20 _stakingToken,
        address _beneficiary,
        uint256 _amount,
        bytes32 _proposalId
    ) external onlyVotingMachine returns (bool) {
        return ControllerInterface(avatar.owner()).externalTokenTransfer(_stakingToken, _beneficiary, _amount, avatar);
    }

    function balanceOfStakingToken(IERC20 _stakingToken, bytes32 _proposalId) external view returns (uint256) {
        return _stakingToken.balanceOf(address(avatar));
    }

    function getTotalReputationSupply(bytes32 _proposalId) external view returns (uint256) {
        return Avatar(avatar).nativeReputation().totalSupplyAt(proposalsBlockNumber[_proposalId]);
    }

    function reputationOf(address _owner, bytes32 _proposalId) external view returns (uint256) {
        return Avatar(avatar).nativeReputation().balanceOfAt(_owner, proposalsBlockNumber[_proposalId]);
    }
}
