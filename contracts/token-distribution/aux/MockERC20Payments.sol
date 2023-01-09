// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

/**
@title Exorde Network ERC20 Token v1
@author Mathias Dail - CTO @ Exorde Labs
*/

contract MockUSDC is  ERC20Capped {
    constructor() ERC20 ("Mock USDC", "mUSDC") ERC20Capped(1000*(10**6)*(10**18)) {
        _mint(msg.sender, 1000*(10**6)*(10**6)); 
    }
}
contract MockDAI is  ERC20Capped {
    constructor() ERC20 ("Mock DAI", "mDAI") ERC20Capped(1000*(10**6)*(10**18)) {
        _mint(msg.sender, 1000*(10**6)*(10**18)); 
    }
}
contract MockUSDT is  ERC20Capped {
    constructor() ERC20 ("Mock USDT", "mUSDT") ERC20Capped(1000*(10**6)*(10**18)) {
        _mint(msg.sender, 1000*(10**6)*(10**6)); 
    }
}
