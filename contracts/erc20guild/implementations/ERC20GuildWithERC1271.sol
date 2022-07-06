// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1271Upgradeable.sol";
import "../ERC20GuildUpgradeable.sol";

/*
  @title ERC20GuildWithERC1271
  @author github:AugustoL
  @dev The guild can sign EIP1271 messages, to do this the guild needs to call itself and allow the signature to be verified 
    with and extra signature of any account with voting power.
*/
contract ERC20GuildWithERC1271 is ERC20GuildUpgradeable, IERC1271Upgradeable {
    using SafeMathUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    // The EIP1271 hashes that were signed by the ERC20Guild
    // Once a hash is signed by the guild it can be verified with a signature from any voter with balance
    mapping(bytes32 => bool) public EIP1271SignedHashes;

    // @dev Initilizer
    // @param _token The ERC20 token that will be used as source of voting power
    // @param _proposalTime The amount of time in seconds that a proposal will be active for voting
    // @param _timeForExecution The amount of time in seconds that a proposal action will have to execute successfully
    // @param _votingPowerForProposalExecution The percentage of voting power in base 10000 needed to execute a proposal
    // action
    // @param _votingPowerForProposalCreation The percentage of voting power in base 10000 needed to create a proposal
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
        require(address(_token) != address(0), "ERC20GuildWithERC1271: token cant be zero address");
        require(_proposalTime > 0, "ERC20GuildWithERC1271: proposal time has to be more tha 0");
        require(
            _lockTime >= _proposalTime,
            "ERC20GuildWithERC1271: lockTime has to be higher or equal to proposalTime"
        );
        require(
            _votingPowerForProposalExecution > 0,
            "ERC20GuildWithERC1271: voting power for execution has to be more than 0"
        );
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
        permissionRegistry.setPermission(
            address(0),
            address(this),
            address(this),
            bytes4(keccak256("setEIP1271SignedHash(bytes32,bool)")),
            0,
            true
        );
    }

    // @dev Set a hash of an call to be validated using EIP1271
    // @param _hash The EIP1271 hash to be added or removed
    // @param isValid If the hash is valid or not
    function setEIP1271SignedHash(bytes32 _hash, bool isValid) external virtual {
        require(msg.sender == address(this), "ERC20GuildWithERC1271: Only callable by the guild");
        EIP1271SignedHashes[_hash] = isValid;
    }

    // @dev Gets the validity of a EIP1271 hash
    // @param _hash The EIP1271 hash
    function getEIP1271SignedHash(bytes32 _hash) external view virtual returns (bool) {
        return EIP1271SignedHashes[_hash];
    }

    // @dev Get if the hash and signature are valid EIP1271 signatures
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
        return
            ((votingPowerOf(hash.recover(signature)) > 0) && EIP1271SignedHashes[hash])
                ? this.isValidSignature.selector
                : bytes4(0);
    }
}
