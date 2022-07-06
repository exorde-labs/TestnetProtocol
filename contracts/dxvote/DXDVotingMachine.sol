pragma solidity ^0.5.11;

import "../daostack/votingMachines/GenesisProtocol.sol";

/**
 * @title GenesisProtocol implementation designed for DXdao
 *
 * New Features:
 *  - Payable Votes: Any organization can send funds and configure the gas and maxGasPrice to be refunded per vote.
 *  - Signed Votes: Votes can be signed for this or any voting machine, they can be shared on this voting machine and
 *    execute votes signed for this voting machine.
 *  - Signal Votes: Voters can signal their decisions with near 50k gas, the signaled votes can be executed on
 *    chain by anyone.
 */
contract DXDVotingMachine is GenesisProtocol {
    uint256 private constant MAX_BOOSTED_PROPOSALS = 4096;

    // organization id scheme => parameters hash => required % of votes in boosted proposal.
    // 100 == 1%, 2500 == 25%.
    mapping(bytes32 => mapping(bytes32 => uint256)) public boostedVoteRequiredPercentage;

    struct OrganizationRefunds {
        uint256 balance;
        uint256 voteGas;
        uint256 maxGasPrice;
    }

    mapping(address => OrganizationRefunds) public organizationRefunds;

    // Event used to share vote signatures on chain
    event VoteSigned(
        address votingMachine,
        bytes32 proposalId,
        address voter,
        uint256 voteDecision,
        uint256 amount,
        bytes signature
    );

    struct VoteDecision {
        uint256 voteDecision;
        uint256 amount;
    }

    mapping(bytes32 => mapping(address => VoteDecision)) public votesSignaled;

    // The number of choices of each proposal
    mapping(bytes32 => uint256) internal numOfChoices;

    // Event used to signal votes to be executed on chain
    event VoteSignaled(bytes32 proposalId, address voter, uint256 voteDecision, uint256 amount);

    modifier validDecision(bytes32 proposalId, uint256 decision) {
        require(decision <= getNumberOfChoices(proposalId) && decision > 0, "wrong decision value");
        _;
    }

    /**
     * @dev Constructor
     */
    constructor(IERC20 _stakingToken) public GenesisProtocol(_stakingToken) {
        require(address(_stakingToken) != address(0), "wrong _stakingToken");
        stakingToken = _stakingToken;
    }

    /**
     * @dev Allows the voting machine to receive ether to be used to refund voting costs
     */
    function() external payable {
        require(
            organizationRefunds[msg.sender].voteGas > 0,
            "DXDVotingMachine: Address not registered in organizationRefounds"
        );
        organizationRefunds[msg.sender].balance = organizationRefunds[msg.sender].balance.add(msg.value);
    }

    /**
     * @dev Config the vote refund for each organization
     * @param _voteGas the amount of gas that will be used as vote cost
     * @param _maxGasPrice the maximum amount of gas price to be paid, if the gas used is higher than this value only a
     * portion of the total gas would be refunded
     */
    function setOrganizationRefund(uint256 _voteGas, uint256 _maxGasPrice) external {
        organizationRefunds[msg.sender].voteGas = _voteGas;
        organizationRefunds[msg.sender].maxGasPrice = _maxGasPrice;
    }

    /**
     * @dev Withdraw organization refund balance
     */
    function withdrawRefundBalance() public {
        require(
            organizationRefunds[msg.sender].voteGas > 0,
            "DXDVotingMachine: Address not registered in organizationRefounds"
        );
        require(organizationRefunds[msg.sender].balance > 0, "DXDVotingMachine: Organization refund balance is zero");
        msg.sender.transfer(organizationRefunds[msg.sender].balance);
        organizationRefunds[msg.sender].balance = 0;
    }

    /**
     * @dev Config the required % of votes needed in a boosted proposal in a scheme, only callable by the avatar
     * @param _scheme the scheme address to be configured
     * @param _paramsHash the parameters configuration hashed of the scheme
     * @param _boostedVotePeriodLimit the required % of votes needed in a boosted proposal to be executed on that scheme
     */
    function setBoostedVoteRequiredPercentage(
        address _scheme,
        bytes32 _paramsHash,
        uint256 _boostedVotePeriodLimit
    ) external {
        boostedVoteRequiredPercentage[keccak256(abi.encodePacked(_scheme, msg.sender))][
            _paramsHash
        ] = _boostedVotePeriodLimit;
    }

    /**
     * @dev voting function from old voting machine changing only the logic to refund vote after vote done
     *
     * @param _proposalId id of the proposal
     * @param _vote NO(2) or YES(1).
     * @param _amount the reputation amount to vote with, 0 will use all available REP
     * @param _voter voter address
     * @return bool if the proposal has been executed or not
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
            require(msg.sender == params.voteOnBehalf, "address not allowed to vote on behalf");
            voter = _voter;
        } else {
            voter = msg.sender;
        }
        bool voteResult = internalVote(_proposalId, voter, _vote, _amount);
        _refundVote(proposal.organizationId);
        return voteResult;
    }

    /**
     * @dev Share the vote of a proposal for a voting machine on a event log
     *
     * @param votingMachine the voting machine address
     * @param proposalId id of the proposal
     * @param voter address of voter
     * @param voteDecision the vote decision, NO(2) or YES(1).
     * @param amount the reputation amount to vote with, 0 will use all available REP
     * @param signature the encoded vote signature
     */
    function shareSignedVote(
        address votingMachine,
        bytes32 proposalId,
        address voter,
        uint256 voteDecision,
        uint256 amount,
        bytes calldata signature
    ) external validDecision(proposalId, voteDecision) {
        bytes32 voteHashed = hashVote(votingMachine, proposalId, voter, voteDecision, amount);
        require(voter == voteHashed.toEthSignedMessageHash().recover(signature), "wrong signer");
        emit VoteSigned(votingMachine, proposalId, voter, voteDecision, amount, signature);
    }

    /**
     * @dev Signal the vote of a proposal in this voting machine to be executed later
     *
     * @param proposalId id of the proposal to vote
     * @param voteDecision the vote decisions, NO(2) or YES(1).
     * @param amount the reputation amount to vote with, 0 will use all available REP
     */
    function signalVote(
        bytes32 proposalId,
        uint256 voteDecision,
        uint256 amount
    ) external validDecision(proposalId, voteDecision) {
        require(_isVotable(proposalId), "not votable proposal");
        require(votesSignaled[proposalId][msg.sender].voteDecision == 0, "already voted");
        votesSignaled[proposalId][msg.sender].voteDecision = voteDecision;
        votesSignaled[proposalId][msg.sender].amount = amount;
        emit VoteSignaled(proposalId, msg.sender, voteDecision, amount);
    }

    /**
     * @dev Execute a signed vote
     *
     * @param votingMachine the voting machine address
     * @param proposalId id of the proposal to execute the vote on
     * @param voter the signer of the vote
     * @param voteDecision the vote decision, NO(2) or YES(1).
     * @param amount the reputation amount to vote with, 0 will use all available REP
     * @param signature the signature of the hashed vote
     */
    function executeSignedVote(
        address votingMachine,
        bytes32 proposalId,
        address voter,
        uint256 voteDecision,
        uint256 amount,
        bytes calldata signature
    ) external {
        require(votingMachine == address(this), "wrong votingMachine");
        require(_isVotable(proposalId), "not votable proposal");
        require(
            voter ==
                hashVote(votingMachine, proposalId, voter, voteDecision, amount).toEthSignedMessageHash().recover(
                    signature
                ),
            "wrong signer"
        );
        internalVote(proposalId, voter, voteDecision, amount);
        _refundVote(proposals[proposalId].organizationId);
    }

    /**
     * @dev register a new proposal with the given parameters. Every proposal has a unique ID which is being
     * generated by calculating keccak256 of a incremented counter.
     * @param _paramsHash parameters hash
     * @param _proposer address
     * @param _organization address
     */
    function propose(
        uint256,
        bytes32 _paramsHash,
        address _proposer,
        address _organization
    ) external returns (bytes32) {
        return _propose(NUM_OF_CHOICES, _paramsHash, _proposer, _organization);
    }

    /**
     * @dev register a new proposal with the given parameters. Every proposal has a unique ID which is being
     * generated by calculating keccak256 of a incremented counter.
     * @param _choicesAmount the total amount of choices for the proposal
     * @param _paramsHash parameters hash
     * @param _proposer address
     * @param _organization address
     */
    function proposeMultipleChoice(
        uint256 _choicesAmount,
        bytes32 _paramsHash,
        address _proposer,
        address _organization
    ) external returns (bytes32) {
        return _propose(_choicesAmount, _paramsHash, _proposer, _organization);
    }

    /**
     * @dev staking function
     * @param _proposalId id of the proposal
     * @param _vote  NO(2) or YES(1).
     * @param _amount the betting amount
     * @return bool true - the proposal has been executed
     *              false - otherwise.
     */
    function _stake(
        bytes32 _proposalId,
        uint256 _vote,
        uint256 _amount,
        address _staker
    ) internal validDecision(_proposalId, _vote) returns (bool) {
        // 0 is not a valid vote.
        require(_amount > 0, "staking amount should be >0");

        if (_execute(_proposalId)) {
            return true;
        }
        Proposal storage proposal = proposals[_proposalId];

        if ((proposal.state != ProposalState.PreBoosted) && (proposal.state != ProposalState.Queued)) {
            return false;
        }

        // enable to increase stake only on the previous stake vote
        Staker storage staker = proposal.stakers[_staker];
        if ((staker.amount > 0) && (staker.vote != _vote)) {
            return false;
        }

        uint256 amount = _amount;
        require(stakingToken.transferFrom(_staker, address(this), amount), "fail transfer from staker");
        proposal.totalStakes = proposal.totalStakes.add(amount); //update totalRedeemableStakes
        staker.amount = staker.amount.add(amount);
        // This is to prevent average downstakes calculation overflow
        // Note that GEN cap is 100000000 ether.
        require(staker.amount <= 0x100000000000000000000000000000000, "staking amount is too high");
        require(
            proposal.totalStakes <= uint256(0x100000000000000000000000000000000).sub(proposal.daoBountyRemain),
            "total stakes is too high"
        );

        if (_vote == YES) {
            staker.amount4Bounty = staker.amount4Bounty.add(amount);
        }
        staker.vote = _vote;

        proposal.stakes[_vote] = amount.add(proposal.stakes[_vote]);
        emit Stake(_proposalId, organizations[proposal.organizationId], _staker, _vote, _amount);
        return _execute(_proposalId);
    }

    /**
     * @dev register a new proposal with the given parameters. Every proposal has a unique ID which is being
     * generated by calculating keccak256 of a incremented counter.
     * @param _choicesAmount the total amount of choices for the proposal
     * @param _paramsHash parameters hash
     * @param _proposer address
     * @param _organization address
     */
    function _propose(
        uint256 _choicesAmount,
        bytes32 _paramsHash,
        address _proposer,
        address _organization
    ) internal returns (bytes32) {
        require(_choicesAmount >= NUM_OF_CHOICES);
        // solhint-disable-next-line not-rely-on-time
        require(now > parameters[_paramsHash].activationTime, "not active yet");
        //Check parameters existence.
        require(parameters[_paramsHash].queuedVoteRequiredPercentage >= 50);
        // Generate a unique ID:
        bytes32 proposalId = keccak256(abi.encodePacked(this, proposalsCnt));
        proposalsCnt = proposalsCnt.add(1);
        // Open proposal:
        Proposal memory proposal;
        proposal.callbacks = msg.sender;
        proposal.organizationId = keccak256(abi.encodePacked(msg.sender, _organization));

        proposal.state = ProposalState.Queued;
        // solhint-disable-next-line not-rely-on-time
        proposal.times[0] = now; //submitted time
        proposal.currentBoostedVotePeriodLimit = parameters[_paramsHash].boostedVotePeriodLimit;
        proposal.proposer = _proposer;
        proposal.winningVote = NO;
        proposal.paramsHash = _paramsHash;
        if (organizations[proposal.organizationId] == address(0)) {
            if (_organization == address(0)) {
                organizations[proposal.organizationId] = msg.sender;
            } else {
                organizations[proposal.organizationId] = _organization;
            }
        }
        //calc dao bounty
        uint256 daoBounty = parameters[_paramsHash]
            .daoBountyConst
            .mul(averagesDownstakesOfBoosted[proposal.organizationId])
            .div(100);
        proposal.daoBountyRemain = daoBounty.max(parameters[_paramsHash].minimumDaoBounty);
        proposals[proposalId] = proposal;
        proposals[proposalId].stakes[NO] = proposal.daoBountyRemain; //dao downstake on the proposal
        numOfChoices[proposalId] = _choicesAmount;
        emit NewProposal(proposalId, organizations[proposal.organizationId], _choicesAmount, _proposer, _paramsHash);
        return proposalId;
    }

    /**
     * @dev Vote for a proposal, if the voter already voted, cancel the last vote and set a new one instead
     * @param _proposalId id of the proposal
     * @param _voter used in case the vote is cast for someone else
     * @param _vote a value between 0 to and the proposal's number of choices.
     * @param _rep how many reputation the voter would like to stake for this vote.
     *         if  _rep==0 so the voter full reputation will be use.
     * @return true in case of proposal execution otherwise false
     * throws if proposal is not open or if it has been executed
     * NB: executes the proposal if a decision has been reached
     */
    // solhint-disable-next-line function-max-lines,code-complexity
    function internalVote(
        bytes32 _proposalId,
        address _voter,
        uint256 _vote,
        uint256 _rep
    ) internal validDecision(_proposalId, _vote) returns (bool) {
        if (_execute(_proposalId)) {
            return true;
        }

        Parameters memory params = parameters[proposals[_proposalId].paramsHash];
        Proposal storage proposal = proposals[_proposalId];

        // Check voter has enough reputation:
        uint256 reputation = VotingMachineCallbacksInterface(proposal.callbacks).reputationOf(_voter, _proposalId);
        require(reputation > 0, "_voter must have reputation");
        require(reputation >= _rep, "reputation >= _rep");
        uint256 rep = _rep;
        if (rep == 0) {
            rep = reputation;
        }
        // If this voter has already voted, return false.
        if (proposal.voters[_voter].reputation != 0) {
            return false;
        }
        // The voting itself:
        proposal.votes[_vote] = rep.add(proposal.votes[_vote]);
        //check if the current winningVote changed or there is a tie.
        //for the case there is a tie the current winningVote set to NO.
        if (
            (proposal.votes[_vote] > proposal.votes[proposal.winningVote]) ||
            ((proposal.votes[NO] == proposal.votes[proposal.winningVote]) && proposal.winningVote == YES)
        ) {
            if (
                (proposal.state == ProposalState.Boosted &&
                    ((now - proposal.times[1]) >= (params.boostedVotePeriodLimit - params.quietEndingPeriod))) ||
                // solhint-disable-next-line not-rely-on-time
                proposal.state == ProposalState.QuietEndingPeriod
            ) {
                //quietEndingPeriod
                if (proposal.state != ProposalState.QuietEndingPeriod) {
                    proposal.currentBoostedVotePeriodLimit = params.quietEndingPeriod;
                    proposal.state = ProposalState.QuietEndingPeriod;
                    emit StateChange(_proposalId, proposal.state);
                }
                // solhint-disable-next-line not-rely-on-time
                proposal.times[1] = now;
            }
            proposal.winningVote = _vote;
        }
        proposal.voters[_voter] = Voter({
            reputation: rep,
            vote: _vote,
            preBoosted: ((proposal.state == ProposalState.PreBoosted) || (proposal.state == ProposalState.Queued))
        });
        if ((proposal.state == ProposalState.PreBoosted) || (proposal.state == ProposalState.Queued)) {
            proposal.preBoostedVotes[_vote] = rep.add(proposal.preBoostedVotes[_vote]);
            uint256 reputationDeposit = (params.votersReputationLossRatio.mul(rep)) / 100;
            VotingMachineCallbacksInterface(proposal.callbacks).burnReputation(reputationDeposit, _voter, _proposalId);
        }
        emit VoteProposal(_proposalId, organizations[proposal.organizationId], _voter, _vote, rep);
        return _execute(_proposalId);
    }

    /**
     * @dev Execute a signed vote on a votable proposal
     *
     * @param proposalId id of the proposal to vote
     * @param voter the signer of the vote
     */
    function executeSignaledVote(bytes32 proposalId, address voter) external {
        require(_isVotable(proposalId), "not votable proposal");
        require(votesSignaled[proposalId][voter].voteDecision > 0, "wrong vote shared");
        internalVote(
            proposalId,
            voter,
            votesSignaled[proposalId][voter].voteDecision,
            votesSignaled[proposalId][voter].amount
        );
        delete votesSignaled[proposalId][voter];
        _refundVote(proposals[proposalId].organizationId);
    }

    /**
     * @dev Refund a vote gas cost to an address
     *
     * @param organizationId the id of the organization that should do the refund
     */
    function _refundVote(bytes32 organizationId) internal {
        address orgAddress = organizations[organizationId];
        if (organizationRefunds[orgAddress].voteGas > 0) {
            uint256 gasRefund = organizationRefunds[orgAddress].voteGas.mul(
                tx.gasprice.min(organizationRefunds[orgAddress].maxGasPrice)
            );
            if (organizationRefunds[orgAddress].balance >= gasRefund) {
                organizationRefunds[orgAddress].balance = organizationRefunds[orgAddress].balance.sub(gasRefund);
                msg.sender.transfer(gasRefund);
            }
        }
    }

    /**
     * @dev Hash the vote data that is used for signatures
     *
     * @param votingMachine the voting machine address
     * @param proposalId id of the proposal
     * @param voter the signer of the vote
     * @param voteDecision the vote decision, NO(2) or YES(1).
     * @param amount the reputation amount to vote with, 0 will use all available REP
     */
    function hashVote(
        address votingMachine,
        bytes32 proposalId,
        address voter,
        uint256 voteDecision,
        uint256 amount
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(votingMachine, proposalId, voter, voteDecision, amount));
    }

    /**
     * @dev proposalStatusWithVotes return the total votes, preBoostedVotes and stakes for a given proposal
     * @param _proposalId the ID of the proposal
     * @return uint256 votes YES
     * @return uint256 votes NO
     * @return uint256 preBoostedVotes YES
     * @return uint256 preBoostedVotes NO
     * @return uint256 total stakes YES
     * @return uint256 total stakes NO
     */
    function proposalStatusWithVotes(bytes32 _proposalId)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            proposals[_proposalId].votes[YES],
            proposals[_proposalId].votes[NO],
            proposals[_proposalId].preBoostedVotes[YES],
            proposals[_proposalId].preBoostedVotes[NO],
            proposals[_proposalId].stakes[YES],
            proposals[_proposalId].stakes[NO]
        );
    }

    /**
     * @dev Get the required % of votes needed in a boosted proposal in a scheme
     * @param avatar the avatar address
     * @param scheme the scheme address
     * @param paramsHash the parameters configuration hashed of the scheme
     */
    function getBoostedVoteRequiredPercentage(
        address avatar,
        address scheme,
        bytes32 paramsHash
    ) external view returns (uint256) {
        return boostedVoteRequiredPercentage[keccak256(abi.encodePacked(scheme, avatar))][paramsHash];
    }

    /**
     * @dev getNumberOfChoices returns the number of choices possible in this proposal
     * @param _proposalId the proposal id
     * @return uint256 that contains number of choices
     */
    function getNumberOfChoices(bytes32 _proposalId) public view returns (uint256) {
        return numOfChoices[_proposalId];
    }

    /**
     * @dev execute check if the proposal has been decided, and if so, execute the proposal
     * @param _proposalId the id of the proposal
     * @return bool true - the proposal has been executed
     *              false - otherwise.
     */
    // solhint-disable-next-line function-max-lines,code-complexity
    function _execute(bytes32 _proposalId) internal votable(_proposalId) returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        Parameters memory params = parameters[proposal.paramsHash];
        Proposal memory tmpProposal = proposal;
        uint256 totalReputation = VotingMachineCallbacksInterface(proposal.callbacks).getTotalReputationSupply(
            _proposalId
        );
        //first divide by 100 to prevent overflow
        uint256 executionBar = (totalReputation / 100) * params.queuedVoteRequiredPercentage;
        uint256 _boostedVoteRequiredPercentage = boostedVoteRequiredPercentage[proposal.organizationId][
            proposal.paramsHash
        ];
        uint256 boostedExecutionBar = (totalReputation / 10000) * _boostedVoteRequiredPercentage;
        ExecutionState executionState = ExecutionState.None;
        uint256 averageDownstakesOfBoosted;
        uint256 confidenceThreshold;

        if (proposal.votes[proposal.winningVote] > executionBar) {
            // someone crossed the absolute vote execution bar.
            if (proposal.state == ProposalState.Queued) {
                executionState = ExecutionState.QueueBarCrossed;
            } else if (proposal.state == ProposalState.PreBoosted) {
                executionState = ExecutionState.PreBoostedBarCrossed;
            } else {
                executionState = ExecutionState.BoostedBarCrossed;
            }
            proposal.state = ProposalState.Executed;
        } else {
            if (proposal.state == ProposalState.Queued) {
                // solhint-disable-next-line not-rely-on-time
                if ((now - proposal.times[0]) >= params.queuedVotePeriodLimit) {
                    proposal.state = ProposalState.ExpiredInQueue;
                    proposal.winningVote = NO;
                    executionState = ExecutionState.QueueTimeOut;
                } else {
                    confidenceThreshold = threshold(proposal.paramsHash, proposal.organizationId);
                    if (_score(_proposalId) > confidenceThreshold) {
                        //change proposal mode to PreBoosted mode.
                        proposal.state = ProposalState.PreBoosted;
                        // solhint-disable-next-line not-rely-on-time
                        proposal.times[2] = now;
                        proposal.confidenceThreshold = confidenceThreshold;
                    }
                }
            }

            if (proposal.state == ProposalState.PreBoosted) {
                confidenceThreshold = threshold(proposal.paramsHash, proposal.organizationId);
                // solhint-disable-next-line not-rely-on-time
                if ((now - proposal.times[2]) >= params.preBoostedVotePeriodLimit) {
                    if (_score(_proposalId) > confidenceThreshold) {
                        if (orgBoostedProposalsCnt[proposal.organizationId] < MAX_BOOSTED_PROPOSALS) {
                            //change proposal mode to Boosted mode.
                            proposal.state = ProposalState.Boosted;

                            // ONLY CHANGE IN DXD VOTING MACHINE TO BOOST AUTOMATICALLY
                            proposal.times[1] = proposal.times[2] + params.preBoostedVotePeriodLimit;

                            orgBoostedProposalsCnt[proposal.organizationId]++;
                            //add a value to average -> average = average + ((value - average) / nbValues)
                            averageDownstakesOfBoosted = averagesDownstakesOfBoosted[proposal.organizationId];
                            // solium-disable-next-line indentation
                            averagesDownstakesOfBoosted[proposal.organizationId] = uint256(
                                int256(averageDownstakesOfBoosted) +
                                    ((int256(proposal.stakes[NO]) - int256(averageDownstakesOfBoosted)) /
                                        int256(orgBoostedProposalsCnt[proposal.organizationId]))
                            );
                        }
                    } else {
                        proposal.state = ProposalState.Queued;
                    }
                } else {
                    //check the Confidence level is stable
                    uint256 proposalScore = _score(_proposalId);
                    if (proposalScore <= proposal.confidenceThreshold.min(confidenceThreshold)) {
                        proposal.state = ProposalState.Queued;
                    } else if (proposal.confidenceThreshold > proposalScore) {
                        proposal.confidenceThreshold = confidenceThreshold;
                        emit ConfidenceLevelChange(_proposalId, confidenceThreshold);
                    }
                }
            }
        }

        if ((proposal.state == ProposalState.Boosted) || (proposal.state == ProposalState.QuietEndingPeriod)) {
            // solhint-disable-next-line not-rely-on-time
            if ((now - proposal.times[1]) >= proposal.currentBoostedVotePeriodLimit) {
                if (proposal.votes[proposal.winningVote] >= boostedExecutionBar) {
                    proposal.state = ProposalState.Executed;
                    executionState = ExecutionState.BoostedBarCrossed;
                } else {
                    proposal.state = ProposalState.ExpiredInQueue;
                    proposal.winningVote = NO;
                    executionState = ExecutionState.BoostedTimeOut;
                }
            }
        }

        if (executionState != ExecutionState.None) {
            if (
                (executionState == ExecutionState.BoostedTimeOut) ||
                (executionState == ExecutionState.BoostedBarCrossed)
            ) {
                orgBoostedProposalsCnt[tmpProposal.organizationId] = orgBoostedProposalsCnt[tmpProposal.organizationId]
                    .sub(1);
                //remove a value from average = ((average * nbValues) - value) / (nbValues - 1);
                uint256 boostedProposals = orgBoostedProposalsCnt[tmpProposal.organizationId];
                if (boostedProposals == 0) {
                    averagesDownstakesOfBoosted[proposal.organizationId] = 0;
                } else {
                    averageDownstakesOfBoosted = averagesDownstakesOfBoosted[proposal.organizationId];
                    averagesDownstakesOfBoosted[proposal.organizationId] =
                        (averageDownstakesOfBoosted.mul(boostedProposals + 1).sub(proposal.stakes[NO])) /
                        boostedProposals;
                }
            }
            emit ExecuteProposal(
                _proposalId,
                organizations[proposal.organizationId],
                proposal.winningVote,
                totalReputation
            );
            emit GPExecuteProposal(_proposalId, executionState);
            proposal.daoBounty = proposal.daoBountyRemain;
            ProposalExecuteInterface(proposal.callbacks).executeProposal(_proposalId, int256(proposal.winningVote));
        }
        if (tmpProposal.state != proposal.state) {
            emit StateChange(_proposalId, proposal.state);
        }
        return (executionState != ExecutionState.None);
    }
}
