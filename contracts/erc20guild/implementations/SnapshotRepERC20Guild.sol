// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "../ERC20GuildUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "../../utils/ERC20/ERC20SnapshotRep.sol";

/*
  @title SnapshotRepERC20Guild
  @author github:AugustoL
  @dev An ERC20Guild designed to work with a snapshotted voting token, no locking needed.
  When a proposal is created it saves the snapshot if at the moment of creation,
  the voters can vote only with the voting power they had at that time.
*/
contract SnapshotRepERC20Guild is ERC20GuildUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using MathUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    // Proposal id => Snapshot id
    mapping(bytes32 => uint256) public proposalsSnapshots;

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
    ) public override initializer {
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
            _token,
            bytes4(keccak256("mint(address,uint256)")),
            0,
            true
        );
        permissionRegistry.setPermission(
            address(0),
            address(this),
            _token,
            bytes4(keccak256("burn(address,uint256)")),
            0,
            true
        );
    }

    // @dev Set the voting power to vote in a proposal
    // @param proposalId The id of the proposal to set the vote
    // @param action The proposal action to be voted
    // @param votingPower The votingPower to use in the proposal
    function setVote(
        bytes32 proposalId,
        uint256 action,
        uint256 votingPower
    ) public virtual override {
        _setSnapshottedVote(msg.sender, proposalId, action, votingPower);
    }

    // @dev Set the voting power to vote in a proposal using a signed vote
    // @param proposalId The id of the proposal to set the vote
    // @param action The proposal action to be voted
    // @param votingPower The votingPower to use in the proposal
    // @param voter The address of the voter
    // @param signature The signature of the hashed vote
    function setSignedVote(
        bytes32 proposalId,
        uint256 action,
        uint256 votingPower,
        address voter,
        bytes memory signature
    ) public virtual override {
        bytes32 hashedVote = hashVote(voter, proposalId, action, votingPower);
        require(!signedVotes[hashedVote], "SnapshotERC20Guild: Already voted");
        require(voter == hashedVote.toEthSignedMessageHash().recover(signature), "SnapshotERC20Guild: Wrong signer");
        signedVotes[hashedVote] = true;
        _setSnapshottedVote(voter, proposalId, action, votingPower);
    }

    // @dev Override and disable lock of tokens, not needed in SnapshotRepERC20Guild
    function lockTokens(uint256) external virtual override {
        revert("SnapshotERC20Guild: token vault disabled");
    }

    // @dev Override and disable withdraw of tokens, not needed in SnapshotRepERC20Guild
    function withdrawTokens(uint256) external virtual override {
        revert("SnapshotERC20Guild: token vault disabled");
    }

    // @dev Create a proposal with an static call data and extra information
    // @param to The receiver addresses of each call to be executed
    // @param data The data to be executed on each call to be executed
    // @param value The ETH value to be sent on each call to be executed
    // @param totalActions The amount of actions that would be offered to the voters
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
        bytes32 proposalId = super.createProposal(to, data, value, totalActions, title, contentHash);
        proposalsSnapshots[proposalId] = ERC20SnapshotRep(address(token)).getCurrentSnapshotId();
        return proposalId;
    }

    // @dev Internal function to set the amount of votingPower to vote in a proposal based on the proposal snapshot
    // @param voter The address of the voter
    // @param proposalId The id of the proposal to set the vote
    // @param action The proposal action to be voted
    // @param votingPower The amount of votingPower to use as voting for the proposal
    function _setSnapshottedVote(
        address voter,
        bytes32 proposalId,
        uint256 action,
        uint256 votingPower
    ) internal {
        require(proposals[proposalId].endTime > block.timestamp, "SnapshotERC20Guild: Proposal ended, cant be voted");
        require(
            votingPowerOfAt(voter, proposalsSnapshots[proposalId]) >= votingPower,
            "SnapshotERC20Guild: Invalid votingPower amount"
        );
        require(
            votingPower > proposalVotes[proposalId][voter].votingPower,
            "SnapshotERC20Guild: Cant decrease votingPower in vote"
        );
        require(
            proposalVotes[proposalId][voter].action == 0 || proposalVotes[proposalId][voter].action == action,
            "SnapshotERC20Guild: Cant change action voted, only increase votingPower"
        );

        proposals[proposalId].totalVotes[action] = proposals[proposalId]
            .totalVotes[action]
            .sub(proposalVotes[proposalId][voter].votingPower)
            .add(votingPower);

        proposalVotes[proposalId][voter].action = action;
        proposalVotes[proposalId][voter].votingPower = votingPower;

        emit VoteAdded(proposalId, action, voter, votingPower);

        if (voteGas > 0) {
            uint256 gasRefund = voteGas.mul(tx.gasprice.min(maxGasPrice));
            if (address(this).balance >= gasRefund) {
                (bool success, ) = payable(msg.sender).call{value: gasRefund}("");
                require(success, "Failed to refund gas");
            }
        }
    }

    // @dev Get the voting power of multiple addresses at a certain snapshotId
    // @param accounts The addresses of the accounts
    // @param snapshotIds The snapshotIds to be used
    function votingPowerOfMultipleAt(address[] memory accounts, uint256[] memory snapshotIds)
        external
        view
        virtual
        returns (uint256[] memory)
    {
        uint256[] memory votes = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) votes[i] = votingPowerOfAt(accounts[i], snapshotIds[i]);
        return votes;
    }

    // @dev Get the voting power of an address at a certain snapshotId
    // @param account The address of the account
    // @param snapshotId The snapshotId to be used
    function votingPowerOfAt(address account, uint256 snapshotId) public view virtual returns (uint256) {
        return ERC20SnapshotRep(address(token)).balanceOfAt(account, snapshotId);
    }

    // @dev Get the voting power of an account
    // @param account The address of the account
    function votingPowerOf(address account) public view virtual override returns (uint256) {
        return ERC20SnapshotRep(address(token)).balanceOf(account);
    }

    // @dev Get the proposal snapshot id
    function getProposalSnapshotId(bytes32 proposalId) external view returns (uint256) {
        return proposalsSnapshots[proposalId];
    }
}
