// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

import "../daostack/controller/Avatar.sol";

contract ExordeAvatar is Avatar {
    constructor(
        string memory _orgName,
        DAOToken _nativeToken,
        Reputation _nativeReputation
    ) Avatar(_orgName, _nativeToken, _nativeReputation) {}
}
