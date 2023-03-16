// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author Mathias Dail, CTO @ Exorde Labs
 * @title Monthly Payout Contract
 * @dev A contract that pays out a fixed monthly amount to a list of users based on their percentages
 */
contract MonthlyPayout is Ownable {
    /*
     * @dev Safe ERC20 token operations.
     */
    using SafeERC20 for IERC20;

    IERC20 public EXDToken = IERC20(0x02dE007D412266a2e0Fa9287C103474170F06560); 
    // EXD token = https://etherscan.io/address/0x02de007d412266a2e0fa9287c103474170f06560

    uint256 constant MAX_PERCENTAGE = 10000; // 10 000 = 100%, for precision

    /*
     * @dev The monthly total amount to be redistributed: in EXD, in 18 decimals (wei unit)
     */
    uint256 public monthlyAmount;
    uint256 public userCount = 0;
    uint256 public initialTimestamp = 1678888800;

    mapping(address => uint256) public percentages; // out of 10000 (1% = 100, 1.33% = 133)
    mapping(address => uint256) public lastPayout;

    event BeneficiaryUpdated(address user, address new_address);

    /**
     * @dev Initializes the contract with the list of users, their percentages, and the monthly payout amount.
     * @param _users The list of users to pay out to
     * @param _percentages The list of percentages for each user (out of 10000)
     * @param _monthlyAmount The fixed monthly payout amount in EXDToken
     */
    constructor(address payable[] memory _users, uint256[] memory _percentages, uint256 _monthlyAmount) {
        require(_users.length == _percentages.length);
        require(_monthlyAmount > 0, "monthlyAmount must be > 0");
        uint256 totalPercentage;
        for (uint256 i = 0; i < _users.length; i++) {
            require(_users[i] != address(0), "Invalid user address");
            require(_percentages[i] <= MAX_PERCENTAGE, "Invalid user percentage");
            percentages[_users[i]] = _percentages[i];
            totalPercentage += _percentages[i];
        }
        require(totalPercentage == MAX_PERCENTAGE, "Total percentage must be 10000");
        userCount += _users.length;
        monthlyAmount = _monthlyAmount;
    }

    /**
     * @dev Allows the contract owner to update the claim percentages for a list of users.
     * @param users_ The list of users to update claim percentages for
     * @param percentages_ The new list of claim percentages for the users (out of 10000)
     */
    function updateClaimPercentages(address[] calldata users_, uint256[] calldata percentages_) public 
    onlyOwner {
        require(users_.length == percentages_.length, "Length of arrays should be equal");        
        for (uint256 i = 0; i < users_.length; i++) {
            require(percentages_[i] <= MAX_PERCENTAGE, "Percentage cannot be greater than 100");
            percentages[users_[i]] = percentages_[i];
        }
    }

    /**
     * @dev Allows the contract owner to update the monthly payout amount.
     * @param _monthlyAmount The new fixed monthly payout amount in EXD Token
     */
    function updateMonthlyAmount(uint256 _monthlyAmount) public 
    onlyOwner {
        monthlyAmount = _monthlyAmount;
    }

    /**
     * @dev Allows the contract owner to update initialTimestamp
     * @param initialTimestamp_ The new initialTimestamp
     */
    function updateInitialTimestamp(uint256 initialTimestamp_) public 
    onlyOwner {
        initialTimestamp = initialTimestamp_;
    }


    /**
     * @dev Allows a beneficiary to claim their share of the monthly distribution.
     */
    function claim() external {
        require(percentages[msg.sender] > 0, "user has no percentage");
        uint256 monthsSinceLastPayout;
        if (lastPayout[msg.sender] == 0){
            monthsSinceLastPayout = (block.timestamp - initialTimestamp) / 30.42 days;
        }
        else{
            monthsSinceLastPayout = (block.timestamp - lastPayout[msg.sender]) / 30.42 days;
        }
        uint256 totalAmount = monthlyAmount * percentages[msg.sender] / MAX_PERCENTAGE * (monthsSinceLastPayout + 1);
        lastPayout[msg.sender] = block.timestamp;
        require(totalAmount > 0, "Nothing to claim");
        SafeERC20.safeTransfer(EXDToken, msg.sender, totalAmount);
    }

    /**
     * @dev Update the beneficiary address
     */
    function transferUserPercentage(address newAddress_) public virtual {
        require(percentages[msg.sender] > 0, "user has no percentage to transfer");
        require(percentages[newAddress_] == 0, "newAddress_ is already a user");
        require(newAddress_ != address(0), "The new beneficiary must be non zero");
        require(newAddress_ != msg.sender, "new address must be different");
        // update new data structure
        percentages[newAddress_] = percentages[msg.sender];
        lastPayout[newAddress_] = lastPayout[msg.sender];
        // delete old data structure
        delete percentages[msg.sender];
        delete lastPayout[msg.sender];
        emit BeneficiaryUpdated(msg.sender, newAddress_);
    }
    
    /**
     * @dev Allows the owner to withdraw unsold ERC20 tokens from the contract.
     * @param token_ The ERC20 token to withdraw.
     * @param beneficiary_ The address to which the tokens will be transferred.
     * @param tokenAmount_ The amount of tokens to be withdrawn.
     */
    function adminWithdrawERC20(IERC20 token_, address beneficiary_, uint256 tokenAmount_) external
    onlyOwner
    {
        token_.safeTransfer(beneficiary_, tokenAmount_);
    }

    /**
     * @dev Returns the current balance of the ERC20 token in the contract.
     */
    function currentEXDBalance() public view  returns(uint256){
        return EXDToken.balanceOf(address(this));
    }
}
