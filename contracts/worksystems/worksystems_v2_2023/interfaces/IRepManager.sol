// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

interface IRepManager {
    function mintReputationForWork(
        uint256 _amount,
        address _beneficiary,
        bytes32
    ) external returns (bool);

    function burnReputationForWork(
        uint256 _amount,
        address _beneficiary,
        bytes32
    ) external returns (bool);
}
