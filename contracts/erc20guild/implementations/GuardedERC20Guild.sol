// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "../ERC20GuildUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/*
  @title GuardedERC20Guild
  @author github:AugustoL
  @dev An ERC20GuildUpgradeable with a guardian, the proposal time can be extended an extra time for the guardian to end the
  proposal like it would happen normally from a base ERC20Guild or reject it directly.
*/
contract GuardedERC20Guild is ERC20GuildUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    address public guildGuardian;
    uint256 public extraTimeForGuardian;

    // @dev Initilizer
    // @param _token The ERC20 token that will be used as source of voting power
    // @param _proposalTime The amount of time in seconds that a proposal will be active for voting
    // @param _timeForExecution The amount of time in seconds that a proposal action will have to execute successfully
    // @param _votingPowerForProposalExecution The percentage of voting power in base 10000 needed to execute a proposal
    // action
    // @param _votingPowerForProposalCreation The percentage of voting power in base 10000 needed to create a proposal
    // @param _name The name of the ERC20Guild
    // @param _voteGas The amount of gas in wei unit used for vote refunds
    // @param _maxGasPrice The maximum gas price used for vote refunds
    // @param _maxActiveProposals The maximum amount of proposals to be active at the same time
    // @param _lockTime The minimum amount of seconds that the tokens would be locked
    // @param _permissionRegistry The address of the permission registry contract to be used
    function initialize(
        address _token,
        uint256 _proposalTime,
        uint256 _timeForExecution,
        uint256 _votingPowerForProposalExecution,
        uint256 _votingPowerForProposalCreation,
        string memory _name,
        uint256 _voteGas,
        uint256 _maxGasPrice,
        uint256 _maxActiveProposals,
        uint256 _lockTime,
        address _permissionRegistry
    ) public virtual override initializer {
        super.initialize(
            _token,
            _proposalTime,
            _timeForExecution,
            _votingPowerForProposalExecution,
            _votingPowerForProposalCreation,
            _name,
            _voteGas,
            _maxGasPrice,
            _maxActiveProposals,
            _lockTime,
            _permissionRegistry
        );
        permissionRegistry.setPermission(
            address(0),
            address(this),
            address(this),
            bytes4(keccak256("setGuardianConfig(address,uint256)")),
            0,
            true
        );
    }

    // @dev Executes a proposal that is not votable anymore and can be finished
    // If this function is called by the guild guardian the proposal can end sooner after proposal endTime
    // If this function is not called by the guild guardian the proposal can end sooner after proposal endTime plus
    // the extraTimeForGuardian
    // @param proposalId The id of the proposal to be executed
    function endProposal(bytes32 proposalId) public virtual override {
        require(proposals[proposalId].state == ProposalState.Active, "GuardedERC20Guild: Proposal already executed");
        if (msg.sender == guildGuardian)
            require(
                (proposals[proposalId].endTime < block.timestamp),
                "GuardedERC20Guild: Proposal hasn't ended yet for guardian"
            );
        else
            require(
                proposals[proposalId].endTime.add(extraTimeForGuardian) < block.timestamp,
                "GuardedERC20Guild: Proposal hasn't ended yet for guild"
            );
        super.endProposal(proposalId);
    }

    // @dev Rejects a proposal directly without execution, only callable by the guardian
    // @param proposalId The id of the proposal to be executed
    function rejectProposal(bytes32 proposalId) external {
        require(proposals[proposalId].state == ProposalState.Active, "GuardedERC20Guild: Proposal already executed");
        require((msg.sender == guildGuardian), "GuardedERC20Guild: Proposal can be rejected only by guardian");
        proposals[proposalId].state = ProposalState.Rejected;
        emit ProposalStateChanged(proposalId, uint256(ProposalState.Rejected));
    }

    // @dev Set GuardedERC20Guild guardian configuration
    // @param _guildGuardian The address of the guild guardian
    // @param _extraTimeForGuardian The extra time the proposals would be locked for guardian verification
    function setGuardianConfig(address _guildGuardian, uint256 _extraTimeForGuardian) external {
        require(
            (guildGuardian == address(0)) || (msg.sender == address(this)),
            "GuardedERC20Guild: Only callable by the guild itself when guildGuardian is set"
        );
        require(_guildGuardian != address(0), "GuardedERC20Guild: guildGuardian cant be address 0");
        guildGuardian = _guildGuardian;
        extraTimeForGuardian = _extraTimeForGuardian;
    }

    // @dev Get the guildGuardian address
    function getGuildGuardian() external view returns (address) {
        return guildGuardian;
    }

    // @dev Get the extraTimeForGuardian
    function getExtraTimeForGuardian() external view returns (uint256) {
        return extraTimeForGuardian;
    }
}
