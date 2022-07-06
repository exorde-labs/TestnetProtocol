// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../utils/PermissionRegistry.sol";
import "../utils/TokenVault.sol";
import "./BaseERC20Guild.sol";

/*
  @title ERC20GuildUpgradeable
  @author github:AugustoL
  @dev Extends an ERC20 functionality into a Guild, adding a simple governance system over an ERC20 token.
  An ERC20Guild is a simple organization that execute arbitrary calls if a minimum amount of votes is reached in a 
  proposal action while the proposal is active.
  The token used for voting needs to be locked for a minimum period of time in order to be used as voting power.
  Every time tokens are locked the timestamp of the lock is updated and increased the lock time seconds.
  Once the lock time passed the voter can withdraw his tokens.
  Each proposal has actions, the voter can vote only once per proposal and cant change the chosen action, only
  increase the voting power of his vote.
  A proposal ends when the minimum amount of total voting power is reached on a proposal action before the proposal
  finish.
  When a proposal ends successfully it executes the calls of the winning action.
  The winning action has a certain amount of time to be executed successfully if that time passes and the action didn't
  executed successfully, it is marked as failed.
  The guild can execute only allowed functions, if a function is not allowed it will need to set the allowance for it.
  The allowed functions have a timestamp that marks from what time the function can be executed.
  A limit to a maximum amount of active proposals can be set, an active proposal is a proposal that is in Active state.
  Gas can be refunded to the account executing the vote, for this to happen the voteGas and maxGasPrice values need to
  be set.
  Signed votes can be executed in behalf of other users, to sign a vote the voter needs to hash it with the function
  hashVote, after signing the hash teh voter can share it to other account to be executed.
  Multiple votes and signed votes can be executed in one transaction.
*/
contract ERC20GuildUpgradeable is BaseERC20Guild, Initializable {
    // @dev Initializer
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
    ) public virtual initializer {
        require(address(_token) != address(0), "ERC20Guild: token cant be zero address");
        require(_proposalTime > 0, "ERC20Guild: proposal time has to be more tha 0");
        require(_lockTime >= _proposalTime, "ERC20Guild: lockTime has to be higher or equal to proposalTime");
        require(_votingPowerForProposalExecution > 0, "ERC20Guild: voting power for execution has to be more than 0");
        name = _name;
        token = IERC20Upgradeable(_token);
        tokenVault = new TokenVault();
        tokenVault.initialize(address(token), address(this));
        proposalTime = _proposalTime;
        timeForExecution = _timeForExecution;
        votingPowerForProposalExecution = _votingPowerForProposalExecution;
        votingPowerForProposalCreation = _votingPowerForProposalCreation;
        voteGas = _voteGas;
        maxGasPrice = _maxGasPrice;
        maxActiveProposals = _maxActiveProposals;
        lockTime = _lockTime;
        permissionRegistry = PermissionRegistry(_permissionRegistry);
        permissionRegistry.setPermission(
            address(0),
            address(this),
            address(this),
            bytes4(keccak256("setConfig(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)")),
            0,
            true
        );
        permissionRegistry.setPermission(
            address(0),
            address(this),
            address(this),
            bytes4(keccak256("setPermission(address[],address[],bytes4[],uint256[],bool[])")),
            0,
            true
        );
        permissionRegistry.setPermission(
            address(0),
            address(this),
            address(this),
            bytes4(keccak256("setPermissionDelay(uint256)")),
            0,
            true
        );
    }
}
