// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Ethereum Mainnet: 0xc948955A1dCA7b46F19Ef6cA876De46aeE6cFaD4
contract ExordeDistribute is Ownable  {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
    * @notice Withdraw (admin/owner only) any tokens from the contract
    */
    function adminWithdrawERC20(IERC20 token_, address beneficiary_, uint256 tokenAmount_) external
    onlyOwner
    {
        token_.safeTransfer(beneficiary_, tokenAmount_);
    }
        
    function getTotalFromAmountList(
        uint256[] calldata _amounts
    ) public view virtual returns (uint256)
    {
        uint256 sum = 0;
        for (uint8 i; i < _amounts.length; i++) {
            sum = sum + _amounts[i];
        }
        return sum;
    }
        
    function multiTransferToken(
        address token_,
        address[] calldata _addresses,
        uint256[] calldata _amounts,
        uint256 _amountSum
    ) payable external
    {
        IERC20 _token =  IERC20(token_);
        require(_token.balanceOf(address(this)) >= _amountSum);
        for (uint8 i; i < _addresses.length; i++) {
            _amountSum = _amountSum.sub(_amounts[i]);
            _token.transfer(_addresses[i], _amounts[i]);
        }
    }
}
