// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";


contract LangManager is Ownable {

    // Languages are identified by an integer index
    mapping(uint256 => string) public langMap; 

    // ------------------------------------------------------------------------------------------

    event LanguageUpdated(uint256 parameters);
    event LanguageAdded(uint256 indexed langId, string langName);
    event LanguageRemoved(uint256 indexed langId, string langName);

    // ------------------------------------------------------------------------------------------


}