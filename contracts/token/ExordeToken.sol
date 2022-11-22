// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract ExordeToken is  ERC20Capped {
    constructor() public ERC20 ("Exorde Network Token", "EXD") ERC20Capped(200*(10**6)) {
        _mint(msg.sender, 200*(10**6)); // 200 000 000 (two hundred millions EXD)
    }
}
