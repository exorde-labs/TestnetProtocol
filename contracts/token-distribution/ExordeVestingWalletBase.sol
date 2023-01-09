// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ExordeVestingWallet is VestingWallet, Ownable{

    uint64 public investor_id; // internal ID
    uint64 public durationSeconds;
    string public info; // extra info/data

    constructor(
        uint64 investor_id_, 
        string memory info_,
        address beneficiaryAddress_,
        uint64 startTimestamp_,
        uint64 durationSeconds_
    ) 
    VestingWallet(beneficiaryAddress_, startTimestamp_, durationSeconds_)
    {
        investor_id = investor_id_;
        durationSeconds = durationSeconds_;
        info = info_;
    }

}
