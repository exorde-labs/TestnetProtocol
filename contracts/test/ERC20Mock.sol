pragma solidity 0.5.17;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";

// mock class using ERC20
contract ERC20Mock is ERC20, ERC20Detailed {
    constructor(address initialAccount, uint256 initialBalance) public ERC20Detailed("EXDT", "Exorde Testnet Token", 18) {
        _mint(initialAccount, initialBalance);
    }
}
