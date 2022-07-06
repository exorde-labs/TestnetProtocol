// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/*
  @title GuildRegistry
  @author github:Kenny-Gin1
  @dev GuildRegistry is a registry with the available guilds. 
  The contracts allows DXdao to add and remove guilds, as well as look up guild addresses.
*/

contract GuildRegistry is Ownable {
    using Counters for Counters.Counter;
    event AddGuild(address guildAddress);
    event RemoveGuild(address guildAddress);

    address[] public guilds;
    Counters.Counter public index;

    mapping(address => uint256) guildsByAddress;

    function addGuild(address guildAddress) external onlyOwner {
        guildsByAddress[guildAddress] = index.current();
        guilds.push(guildAddress);
        index.increment();
        emit AddGuild(guildAddress);
    }

    function removeGuild(address guildAddress) external onlyOwner {
        require(guilds.length > 0, "No guilds to delete");
        // @notice Overwrite the guild we want to delete and then we remove the last element
        uint256 guildIndexToDelete = guildsByAddress[guildAddress];
        address guildAddressToMove = guilds[guilds.length - 1];
        guilds[guildIndexToDelete] = guildAddressToMove;
        guildsByAddress[guildAddress] = guildIndexToDelete;
        guilds.pop();
        index.decrement();
        emit RemoveGuild(guildAddress);
    }

    function getGuildsAddresses() external view returns (address[] memory) {
        return guilds;
    }
}
