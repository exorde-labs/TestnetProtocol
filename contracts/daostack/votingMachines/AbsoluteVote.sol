pragma solidity 0.5.17;

import "../controller/Reputation.sol";
import "./IntVoteInterface.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./VotingMachineCallbacksInterface.sol";
import "./ProposalExecuteInterface.sol";

contract AbsoluteVote is IntVoteInterface {
    using SafeMath for uint256;

    struct Parameters {
        uint256 precReq; // how many percentages required for the proposal to be passed
        address voteOnBehalf; //if this address is set so only this address is allowed
        // to vote of behalf of someone else.
    }

    struct Voter {
        uint256 vote; // 0 - 'abstain'
        uint256 reputation; // amount of voter's reputation
    }

    struct Proposal {
        bytes32 organizationId; // the organization Id
        bool open; // voting open flag
        address callbacks;
        uint256 numOfChoices;
        bytes32 paramsHash; // the hash of the parameters of the proposal
        uint256 totalVotes;
        mapping(uint256 => uint256) votes;
        mapping(address => Voter) voters;
    }

    event AVVoteProposal(bytes32 indexed _proposalId, bool _isProxyVote);

    mapping(bytes32 => Parameters) public parameters; // A mapping from hashes to parameters
    mapping(bytes32 => Proposal) public proposals; // Mapping from the ID of the proposal to the proposal itself.
    mapping(bytes32 => address) public organizations;

    uint256 public constant MAX_NUM_OF_CHOICES = 10;
    uint256 public proposalsCnt; // Total amount of proposals

    /**
     * @dev Check that the proposal is votable (open and not executed yet)
     */
    modifier votable(bytes32 _proposalId) {
        require(proposals[_proposalId].open);
        _;
    }

    /**
     * @dev register a new proposal with the given parameters. Every proposal has a unique ID which is being
     * generated by calculating keccak256 of a incremented counter.
     * @param _numOfChoices number of voting choices
     * @param _paramsHash defined the parameters of the voting machine used for this proposal
     * @param _organization address
     * @return proposal's id.
     */
    function propose(
        uint256 _numOfChoices,
        bytes32 _paramsHash,
        address,
        address _organization
    ) external returns (bytes32) {
        // Check valid params and number of choices:
        require(parameters[_paramsHash].precReq > 0);
        require(_numOfChoices > 0 && _numOfChoices <= MAX_NUM_OF_CHOICES);
        // Generate a unique ID:
        bytes32 proposalId = keccak256(abi.encodePacked(this, proposalsCnt));
        proposalsCnt = proposalsCnt.add(1);
        // Open proposal:
        Proposal memory proposal;
        proposal.numOfChoices = _numOfChoices;
        proposal.paramsHash = _paramsHash;
        proposal.callbacks = msg.sender;
        proposal.organizationId = keccak256(abi.encodePacked(msg.sender, _organization));
        proposal.open = true;
        proposals[proposalId] = proposal;
        if (organizations[proposal.organizationId] == address(0)) {
            if (_organization == address(0)) {
                organizations[proposal.organizationId] = msg.sender;
            } else {
                organizations[proposal.organizationId] = _organization;
            }
        }
        emit NewProposal(proposalId, organizations[proposal.organizationId], _numOfChoices, msg.sender, _paramsHash);
        return proposalId;
    }

    /**
     * @dev voting function
     * @param _proposalId id of the proposal
     * @param _vote a value between 0 to and the proposal number of choices.
     * @param _amount the reputation amount to vote with . if _amount == 0 it will use all voter reputation.
     * @param _voter voter address
     * @return bool true - the proposal has been executed
     *              false - otherwise.
     */
    function vote(
        bytes32 _proposalId,
        uint256 _vote,
        uint256 _amount,
        address _voter
    ) external votable(_proposalId) returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        Parameters memory params = parameters[proposal.paramsHash];
        address voter;
        if (params.voteOnBehalf != address(0)) {
            require(msg.sender == params.voteOnBehalf);
            voter = _voter;
        } else {
            voter = msg.sender;
        }
        return internalVote(_proposalId, voter, _vote, _amount);
    }

    /**
     * @dev Cancel the vote of the msg.sender: subtract the reputation amount from the votes
     * and delete the voter from the proposal struct
     * @param _proposalId id of the proposal
     */
    function cancelVote(bytes32 _proposalId) external votable(_proposalId) {
        cancelVoteInternal(_proposalId, msg.sender);
    }

    /**
     * @dev execute check if the proposal has been decided, and if so, execute the proposal
     * @param _proposalId the id of the proposal
     * @return bool true - the proposal has been executed
     *              false - otherwise.
     */
    function execute(bytes32 _proposalId) external votable(_proposalId) returns (bool) {
        return _execute(_proposalId);
    }

    /**
     * @dev getNumberOfChoices returns the number of choices possible in this proposal
     * excluding the abstain vote (0)
     * @param _proposalId the ID of the proposal
     * @return uint256 that contains number of choices
     */
    function getNumberOfChoices(bytes32 _proposalId) external view returns (uint256) {
        return proposals[_proposalId].numOfChoices;
    }

    /**
     * @dev voteInfo returns the vote and the amount of reputation of the user committed to this proposal
     * @param _proposalId the ID of the proposal
     * @param _voter the address of the voter
     * @return uint256 vote - the voters vote
     *        uint256 reputation - amount of reputation committed by _voter to _proposalId
     */
    function voteInfo(bytes32 _proposalId, address _voter) external view returns (uint256, uint256) {
        Voter memory voter = proposals[_proposalId].voters[_voter];
        return (voter.vote, voter.reputation);
    }

    /**
     * @dev voteStatus returns the reputation voted for a proposal for a specific voting choice.
     * @param _proposalId the ID of the proposal
     * @param _choice the index in the
     * @return voted reputation for the given choice
     */
    function voteStatus(bytes32 _proposalId, uint256 _choice) external view returns (uint256) {
        return proposals[_proposalId].votes[_choice];
    }

    /**
     * @dev isVotable check if the proposal is votable
     * @param _proposalId the ID of the proposal
     * @return bool true or false
     */
    function isVotable(bytes32 _proposalId) external view returns (bool) {
        return proposals[_proposalId].open;
    }

    /**
     * @dev isAbstainAllow returns if the voting machine allow abstain (0)
     * @return bool true or false
     */
    function isAbstainAllow() external pure returns (bool) {
        return true;
    }

    /**
     * @dev getAllowedRangeOfChoices returns the allowed range of choices for a voting machine.
     * @return min - minimum number of choices
               max - maximum number of choices
     */
    function getAllowedRangeOfChoices() external pure returns (uint256 min, uint256 max) {
        return (0, MAX_NUM_OF_CHOICES);
    }

    /**
     * @dev hash the parameters, save them if necessary, and return the hash value
     */
    function setParameters(uint256 _precReq, address _voteOnBehalf) public returns (bytes32) {
        require(_precReq <= 100 && _precReq > 0);
        bytes32 hashedParameters = getParametersHash(_precReq, _voteOnBehalf);
        parameters[hashedParameters] = Parameters({precReq: _precReq, voteOnBehalf: _voteOnBehalf});
        return hashedParameters;
    }

    /**
     * @dev hashParameters returns a hash of the given parameters
     */
    function getParametersHash(uint256 _precReq, address _voteOnBehalf) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_precReq, _voteOnBehalf));
    }

    function cancelVoteInternal(bytes32 _proposalId, address _voter) internal {
        Proposal storage proposal = proposals[_proposalId];
        Voter memory voter = proposal.voters[_voter];
        proposal.votes[voter.vote] = (proposal.votes[voter.vote]).sub(voter.reputation);
        proposal.totalVotes = (proposal.totalVotes).sub(voter.reputation);
        delete proposal.voters[_voter];
        emit CancelVoting(_proposalId, organizations[proposal.organizationId], _voter);
    }

    function deleteProposal(bytes32 _proposalId) internal {
        Proposal storage proposal = proposals[_proposalId];
        for (uint256 cnt = 0; cnt <= proposal.numOfChoices; cnt++) {
            delete proposal.votes[cnt];
        }
        delete proposals[_proposalId];
    }

    /**
     * @dev execute check if the proposal has been decided, and if so, execute the proposal
     * @param _proposalId the id of the proposal
     * @return bool true - the proposal has been executed
     *              false - otherwise.
     */
    function _execute(bytes32 _proposalId) internal votable(_proposalId) returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        uint256 totalReputation = VotingMachineCallbacksInterface(proposal.callbacks).getTotalReputationSupply(
            _proposalId
        );
        uint256 precReq = parameters[proposal.paramsHash].precReq;
        // Check if someone crossed the bar:
        for (uint256 cnt = 0; cnt <= proposal.numOfChoices; cnt++) {
            if (proposal.votes[cnt] > (totalReputation / 100) * precReq) {
                Proposal memory tmpProposal = proposal;
                deleteProposal(_proposalId);
                emit ExecuteProposal(_proposalId, organizations[tmpProposal.organizationId], cnt, totalReputation);
                return ProposalExecuteInterface(tmpProposal.callbacks).executeProposal(_proposalId, int256(cnt));
            }
        }
        return false;
    }

    /**
     * @dev Vote for a proposal, if the voter already voted, cancel the last vote and set a new one instead
     * @param _proposalId id of the proposal
     * @param _voter used in case the vote is cast for someone else
     * @param _vote a value between 0 to and the proposal's number of choices.
     * @return true in case of proposal execution otherwise false
     * throws if proposal is not open or if it has been executed
     * NB: executes the proposal if a decision has been reached
     */
    function internalVote(
        bytes32 _proposalId,
        address _voter,
        uint256 _vote,
        uint256 _rep
    ) internal returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        // Check valid vote:
        require(_vote <= proposal.numOfChoices);
        // Check voter has enough reputation:
        uint256 reputation = VotingMachineCallbacksInterface(proposal.callbacks).reputationOf(_voter, _proposalId);
        require(reputation > 0, "_voter must have reputation");
        require(reputation >= _rep);
        uint256 rep = _rep;
        if (rep == 0) {
            rep = reputation;
        }
        // If this voter has already voted, first cancel the vote:
        if (proposal.voters[_voter].reputation != 0) {
            cancelVoteInternal(_proposalId, _voter);
        }
        // The voting itself:
        proposal.votes[_vote] = rep.add(proposal.votes[_vote]);
        proposal.totalVotes = rep.add(proposal.totalVotes);
        proposal.voters[_voter] = Voter({reputation: rep, vote: _vote});
        // Event:
        emit VoteProposal(_proposalId, organizations[proposal.organizationId], _voter, _vote, rep);
        emit AVVoteProposal(_proposalId, (_voter != msg.sender));
        // execute the proposal if this vote was decisive:
        return _execute(_proposalId);
    }
}
