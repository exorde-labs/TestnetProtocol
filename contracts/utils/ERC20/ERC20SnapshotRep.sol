// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
 * @title ERC20SnapshotRep
 */
contract ERC20SnapshotRep is Initializable, OwnableUpgradeable, ERC20SnapshotUpgradeable {
    using SafeMathUpgradeable for uint256;

    // @dev total holders of Rep tokens
    uint256 public totalHolders;

    function initialize(string memory name, string memory symbol) external initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
    }

    function snapshot() external {
        _snapshot();
    }

    function getCurrentSnapshotId() external view virtual returns (uint256) {
        return _getCurrentSnapshotId();
    }

    function getTotalHolders() external view returns (uint256) {
        return totalHolders;
    }

    function addHolder(address account) internal returns (bool) {
        if (balanceOf(account) == 0) {
            totalHolders = totalHolders.add(1);
            return true;
        } else {
            return false;
        }
    }

    function removeHolder(address account) internal returns (bool) {
        if (balanceOf(account) == 0 && totalHolders > 0) {
            totalHolders = totalHolders.sub(1);
            return true;
        } else {
            return false;
        }
    }

    function mint(address to, uint256 amount) external virtual onlyOwner {
        // @dev we only add to the totalHolders if they did not have tokens prior to minting
        addHolder(to);
        _mint(to, amount);
        _snapshot();
    }

    function burn(address to, uint256 amount) external virtual onlyOwner {
        _burn(to, amount);
        // @dev we only remove from the totalHolders if they do not have tokens after burning
        removeHolder(to);
        _snapshot();
    }
}
