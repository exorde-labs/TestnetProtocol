// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

interface IERC20Guild {
    event ProposalStateChanged(bytes32 indexed proposalId, uint256 newState);
    event VoteAdded(bytes32 indexed proposalId, address voter, uint256 votingPower);
    event SetAllowance(address indexed to, bytes4 functionSignature, bool allowance);

    enum ProposalState {
        None,
        Active,
        Rejected,
        Executed,
        Failed
    }

    struct Vote {
        uint256 action;
        uint256 votingPower;
    }

    struct Proposal {
        address creator;
        uint256 startTime;
        uint256 endTime;
        address[] to;
        bytes[] data;
        uint256[] value;
        string title;
        string contentHash;
        ProposalState state;
        uint256[] totalVotes;
    }

    fallback() external payable;

    receive() external payable;

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
    ) external;

    function setConfig(
        uint256 _proposalTime,
        uint256 _timeForExecution,
        uint256 _votingPowerForProposalExecution,
        uint256 _votingPowerForProposalCreation,
        uint256 _voteGas,
        uint256 _maxGasPrice,
        uint256 _maxActiveProposals,
        uint256 _lockTime,
        address _permissionRegistry
    ) external;

    function setPermission(
        address[] memory asset,
        address[] memory to,
        bytes4[] memory functionSignature,
        uint256[] memory valueAllowed,
        bool[] memory allowance
    ) external;

    function setPermissionDelay(uint256 permissionDelay) external;

    function createProposal(
        address[] memory to,
        bytes[] memory data,
        uint256[] memory value,
        uint256 totalActions,
        string memory title,
        string memory contentHash
    ) external returns (bytes32);

    function endProposal(bytes32 proposalId) external;

    function setVote(
        bytes32 proposalId,
        uint256 action,
        uint256 votingPower
    ) external;

    function setVotes(
        bytes32[] memory proposalIds,
        uint256[] memory actions,
        uint256[] memory votingPowers
    ) external;

    function setSignedVote(
        bytes32 proposalId,
        uint256 action,
        uint256 votingPower,
        address voter,
        bytes memory signature
    ) external;

    function setSignedVotes(
        bytes32[] memory proposalIds,
        uint256[] memory actions,
        uint256[] memory votingPowers,
        address[] memory voters,
        bytes[] memory signatures
    ) external;

    function lockTokens(uint256 tokenAmount) external;

    function withdrawTokens(uint256 tokenAmount) external;

    function votingPowerOf(address account) external view returns (uint256);

    function votingPowerOfMultiple(address[] memory accounts) external view returns (uint256[] memory);

    function getToken() external view returns (address);

    function getPermissionRegistry() external view returns (address);

    function getName() external view returns (string memory);

    function getProposalTime() external view returns (uint256);

    function getTimeForExecution() external view returns (uint256);

    function getVoteGas() external view returns (uint256);

    function getMaxGasPrice() external view returns (uint256);

    function getMaxActiveProposals() external view returns (uint256);

    function getTotalProposals() external view returns (uint256);

    function getTotalMembers() external view returns (uint256);

    function getActiveProposalsNow() external view returns (uint256);

    function getSignedVote(bytes32 signedVoteHash) external view returns (bool);

    function getProposalsIds() external view returns (bytes32[] memory);

    function getTokenVault() external view returns (address);

    function getLockTime() external view returns (uint256);

    function getTotalLocked() external view returns (uint256);

    function getVoterLockTimestamp(address voter) external view returns (uint256);

    function getProposal(bytes32 proposalId) external view returns (Proposal memory);

    function getProposalVotesOfVoter(bytes32 proposalId, address voter)
        external
        view
        returns (uint256 action, uint256 votingPower);

    function getVotingPowerForProposalCreation() external view returns (uint256);

    function getVotingPowerForProposalExecution() external view returns (uint256);

    function getFuncSignature(bytes memory data) external view returns (bytes4);

    function getProposalsIdsLength() external view returns (uint256);

    function getEIP1271SignedHash(bytes32 _hash) external view returns (bool);

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);

    function hashVote(
        address voter,
        bytes32 proposalId,
        uint256 action,
        uint256 votingPower
    ) external pure returns (bytes32);
}
