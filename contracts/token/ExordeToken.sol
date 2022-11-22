// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

/**
@title Exorde Network ERC20 Token v1
@author Mathias Dail - CTO @ Exorde Labs
*/

contract ExordeToken is  ERC20Capped {
    constructor() ERC20 ("Exorde Network Token", "EXD") ERC20Capped(200*(10**6)*(10**18)) {
        _mint(msg.sender, 200*(10**6)*(10**18)); // 200 000 000 (two hundred million) EXD, with 18 decimals (by default)
    }
}
