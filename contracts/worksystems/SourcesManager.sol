// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SourcesManager is Ownable {


    // Sources are identified by an integer index
    // Sources can be a website, a domain name.
    mapping(uint256 => string) public SourcesMap; 

    // ------------------------------------------------------------------------------------------

    event SourceUpdated(uint256 parameters);
    event SourceAdded(uint256 indexed langId, string langName);
    event SourceRemoved(uint256 indexed langId, string langName);


}