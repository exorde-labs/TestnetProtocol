// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.8;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "../utils/ERC20/ERC20SnapshotRep.sol";

// mock class using ERC20SnapshotRep
// @dev We want to expose the internal functions and test them
contract ERC20SnapshotRepMock is ERC20SnapshotUpgradeable, ERC20SnapshotRep {
    constructor() {}

    function _addHolder(address account) public returns (bool) {
        return addHolder(account);
    }

    function _removeHolder(address account) public returns (bool) {
        return removeHolder(account);
    }
}
