// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ERC20Token
 */
contract ERC20Token is Initializable, ERC20Upgradeable {
    function initialize(
        string memory name,
        string memory symbol,
        address _initialAccount,
        uint256 _totalSupply
    ) public initializer {
        __ERC20_init(name, symbol);
        _mint(_initialAccount, _totalSupply);
    }
}
