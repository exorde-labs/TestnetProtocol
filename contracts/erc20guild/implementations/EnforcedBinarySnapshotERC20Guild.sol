// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "./SnapshotERC20Guild.sol";
import "../../utils/Arrays.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

/*
  @title SnapshotERC20Guild
  @author github:AugustoL
  @dev An ERC20Guild designed to work with a snapshotted locked tokens.
  It is an extension over the ERC20Guild where the voters can vote with the voting power used at the moment of the 
  proposal creation.
*/
contract EnforcedBinarySnapshotERC20Guild is SnapshotERC20Guild {
    using SafeMathUpgradeable for uint256;
    using Arrays for uint256[];
    using ECDSAUpgradeable for bytes32;

    // @dev Create a proposal with an static call data and extra information, and a "No" action enforced.
    // @param to The receiver addresses of each call to be executed
    // @param data The data to be executed on each call to be executed
    // @param value The ETH value to be sent on each call to be executed
    // @param totalActions The amount of actions that would be offered to the voters, excluding the "No" action
    // @param title The title of the proposal
    // @param contentHash The content hash of the content reference of the proposal for the proposal to be executed
    function createProposal(
        address[] memory to,
        bytes[] memory data,
        uint256[] memory value,
        uint256 totalActions,
        string memory title,
        string memory contentHash
    ) public virtual override returns (bytes32) {
        require(totalActions > 0, "EnforcedBinarySnapshotERC20Guild: Must have at least one action");
        require(
            (to.length == data.length) && (to.length == value.length),
            "EnforcedBinarySnapshotERC20Guild: Wrong length of to, data or value arrays"
        );
        require(to.length > 0, "EnforcedBinarySnapshotERC20Guild: to, data, value arrays cannot be empty");

        uint256 callsPerAction = to.length.div(totalActions);

        // Clone the arrays amd append the "No" action to the end of them
        address[] memory _to = new address[](to.length + callsPerAction);
        bytes[] memory _data = new bytes[](data.length + callsPerAction);
        uint256[] memory _value = new uint256[](value.length + callsPerAction);

        for (uint256 i = 0; i < to.length; i++) {
            _to[i] = to[i];
            _data[i] = data[i];
            _value[i] = value[i];
        }

        for (uint256 i = to.length; i < _to.length; i++) {
            _to[i] = address(0);
            _data[i] = "";
            _value[i] = 0;
        }
        totalActions = totalActions.add(1);

        return super.createProposal(_to, _data, _value, totalActions, title, contentHash);
    }

    // @dev Executes a proposal that is not votable anymore and can be finished
    // If the most voted option is the "No" option, then the proposal is marked as failed
    // @param proposalId The id of the proposal to be executed
    function endProposal(bytes32 proposalId) public virtual override {
        require(!isExecutingProposal, "EnforcedBinarySnapshotERC20Guild: Proposal under execution");
        require(
            proposals[proposalId].state == ProposalState.Active,
            "EnforcedBinarySnapshotERC20Guild: Proposal already executed"
        );
        require(
            proposals[proposalId].endTime < block.timestamp,
            "EnforcedBinarySnapshotERC20Guild: Proposal hasn't ended yet"
        );

        uint256 winningAction = 0;
        for (uint256 i = 1; i < proposals[proposalId].totalVotes.length; i++) {
            if (
                proposals[proposalId].totalVotes[i] >=
                getVotingPowerForProposalExecution(proposalsSnapshots[proposalId]) &&
                proposals[proposalId].totalVotes[i] > proposals[proposalId].totalVotes[winningAction]
            ) winningAction = i;
        }

        if (winningAction == proposals[proposalId].totalVotes.length - 1) {
            proposals[proposalId].state = ProposalState.Failed;
            emit ProposalStateChanged(proposalId, uint256(ProposalState.Failed));
        } else {
            super.endProposal(proposalId);
        }
    }
}
