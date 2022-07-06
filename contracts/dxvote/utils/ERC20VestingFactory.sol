// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.5.4;

import "openzeppelin-solidity/contracts/drafts/TokenVesting.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract ERC20VestingFactory {
    using SafeERC20 for IERC20;
    event VestingCreated(address vestingContractAddress);

    IERC20 public erc20Token;
    address public vestingOwner;

    constructor(address _erc20Token, address _vestingOwner) public {
        erc20Token = IERC20(_erc20Token);
        vestingOwner = _vestingOwner;
    }

    function create(
        address beneficiary,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        uint256 value
    ) external {
        TokenVesting newVestingContract = new TokenVesting(beneficiary, start, cliffDuration, duration, true);

        erc20Token.transferFrom(msg.sender, address(newVestingContract), value);
        require(
            erc20Token.balanceOf(address(newVestingContract)) >= value,
            "ERC20VestingFactory: token transfer unsuccessful"
        );

        newVestingContract.transferOwnership(vestingOwner);
        emit VestingCreated(address(newVestingContract));
    }
}
