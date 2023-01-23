// SPDX-License-Identifier: MIT

pragma solidity 0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAddressManager {
    function isSenderMasterOf(address _address) external returns (bool);

    function isSenderSubOf(address _master) external returns (bool);

    function isSubAddress(address _master, address _address) external returns (bool);

    function addAddress(address _address) external;

    function removeAddress(address _address) external;
}

interface IParametersManager {
    // -------------- GETTERS : ADDRESSES --------------------
    function getAddressManager() external view returns (address);
}


contract RewardsManager is Ownable {
    event UserRegistered(bytes32 name, uint256 timestamp);
    event UserTransferred(bytes32 name);

    IERC20 public token;
    mapping(address => uint256) public rewards;
    uint256 public ManagerBalance = 0;
    uint256 TotalRewards = 0;
    IParametersManager public Parameters;

    struct TimeframeCounter {
        uint256 timestamp;
        uint256 counter;
    }

    // Cap rewards at 30k EXD per 24 hours, and 1.25k per hour
    uint16 constant NB_TIMEFRAMES_HOURLY = 15;
    uint16 constant TIMEFRAMES_HOURLY_DURATION = 240; // 240*15 = 3600s = 1 hour
    uint16 constant NB_TIMEFRAMES_DAILY = 24;
    uint16 constant TIMEFRAMES_HOURLY_DAILY = 3600; // 3600*24 = 1 day
    TimeframeCounter[NB_TIMEFRAMES_HOURLY] public HourlyRewardsFlowManager;
    TimeframeCounter[NB_TIMEFRAMES_DAILY] public DailyRewardsFlowManager;

    // Hardcoded limit of rewards per hour & day, to limit protocol inflation & rewards exploits
    uint256 public MAX_HOURLY_EXD_REWARDS = 1250*(10**18);
    uint256 public MAX_DAILY_EXD_REWARDS = 30000*(10**18); 

    constructor(
        address EXD_token
    ) {
        token = IERC20(EXD_token);
    }

    /**
     * @notice Updates the Parameters Manager Address
     * @param addr The address of the new contract
     */
    function updateParametersManager(address addr) public onlyOwner {
        require(addr != address(0));
        Parameters = IParametersManager(addr);
    }

    // ------------------------------------------------------------------------------------------

    mapping(address => bool) private RewardsWhitelistMap;
    // addresses of schemes/contracts allowed to interact with Rewardss

    event RewardsWhitelisted(address indexed account, bool isWhitelisted);
    event RewardsUnWhitelisted(address indexed account, bool isWhitelisted);

    /**
     * @notice Returns if a contract address (or user) is whitelisted to interact with rewards
     * @param _address The address
     */
    function isRewardsWhitelisted(address _address) public view returns (bool) {
        return RewardsWhitelistMap[_address];
    }

    /**
     * @notice Adds an address as whitelisted to interact with rewards
     * @param _address The address
     */
    function addAddress(address _address) public onlyOwner {
        require(RewardsWhitelistMap[_address] != true, "RewardsManager: address must not be whitelisted already");
        RewardsWhitelistMap[_address] = true;
        emit RewardsWhitelisted(_address, true);
    }

    /**
     * @notice Removes an address as whitelisted to interact with rewards
     * @param _address The address
     */
    function removeAddress(address _address) public onlyOwner {
        require(RewardsWhitelistMap[_address] != false, "RewardsManager: address must be whitelisted to remove");
        RewardsWhitelistMap[_address] = false;
        emit RewardsUnWhitelisted(_address, false);
    }

    // ---------- EXTERNAL Rewards ALLOCATIONS ----------

    /**
     * @notice A method for a verified whitelisted contract to allocate some Rewards
     * @param _RewardsAllocation The rewards to allocate (distribute)
     * @param _user The address of the user to credit _RewardsAllocation
     */
    function ProxyAddReward(uint256 _RewardsAllocation, address _user) external returns (bool) {
        require(isRewardsWhitelisted(msg.sender), "RewardsManager: sender must be whitelisted to Proxy act");
        // require(ManagerBalance >=  _RewardsAllocation);
        require(_RewardsAllocation > 0, "rewards to allocate must be positive..");
        // ---- Pre rewards distribution limitation check
        require(getDailyRewardsCount() < MAX_DAILY_EXD_REWARDS, "Daily Total Rewards exceed!");
        require(getHourlyRewardsCount() < MAX_HOURLY_EXD_REWARDS, "Hourly Total Rewards exceed!");
        // ---- Pre rewards distribution limitation check
        // check if the contract calling this method has rights to allocate from user Rewards
        if (ManagerBalance >= _RewardsAllocation) {
            ManagerBalance -= _RewardsAllocation;
            rewards[_user] +=  _RewardsAllocation;
            TotalRewards += _RewardsAllocation;
            return true;
        }
        HourlyRewardsFlowManager[HourlyRewardsFlowManager.length - 1].counter +=  _RewardsAllocation;
        DailyRewardsFlowManager[DailyRewardsFlowManager.length - 1].counter +=  _RewardsAllocation;
        // ---- Post rewards distribution limitation check
        updateHourlyRewardsCount();
        updateDailyRewardsCount();
        require(getDailyRewardsCount() < MAX_DAILY_EXD_REWARDS, "Daily Total Rewards exceed!");
        require(getHourlyRewardsCount() < MAX_HOURLY_EXD_REWARDS, "Hourly Total Rewards exceed!");
        // ---- Pre rewards distribution limitation check
        return (false);
    }

    /**
     * @notice A method for a verified whitelisted contract to transfer rewards between two addresses
     * @param _initial The address of the user to transfer from
     * @param _receiving The address of the user to transfer to
     */
    function ProxyTransferRewards(address _initial, address _receiving) external returns (bool) {
        require(isRewardsWhitelisted(msg.sender), "RewardsManager: sender must be whitelisted to Proxy act");
        uint256 _amount_to_transfer = rewards[_initial];
        if (_amount_to_transfer > 0){
            // transfer Rewards
            rewards[_initial] = 0;
            rewards[_receiving] += _amount_to_transfer;
        }
        return true;
    }


    /**
     * @notice Returns the rewards balance (currently withdrawable and available) of a given user
     * @param _address The address of the user
     */
    function RewardsBalanceOf(address _address) public view returns (uint256) {
        return rewards[_address];
    }

    // ---------- ----------

    /**
     * @notice Updates the hourly sliding rewards counter
     */
    function updateHourlyRewardsCount() public {
        uint256 last_timeframe_idx_ = HourlyRewardsFlowManager.length - 1;
        uint256 mostRecentTimestamp_ = HourlyRewardsFlowManager[last_timeframe_idx_].timestamp;
        if ((uint64(block.timestamp) - mostRecentTimestamp_) > TIMEFRAMES_HOURLY_DURATION) {
            // cycle & move periods to the left
            for (uint256 i = 0; i < (HourlyRewardsFlowManager.length - 1); i++) {
                HourlyRewardsFlowManager[i] = HourlyRewardsFlowManager[i + 1];
            }
            //update last timeframe with new values & reset counter
            HourlyRewardsFlowManager[last_timeframe_idx_].timestamp = uint64(block.timestamp);
            HourlyRewardsFlowManager[last_timeframe_idx_].counter = 0;
        }
    }

    /**
     * @notice Updates the daily sliding rewards counter
     */
    function updateDailyRewardsCount() public {
        uint256 last_timeframe_idx_ = DailyRewardsFlowManager.length - 1;
        uint256 mostRecentTimestamp_ = DailyRewardsFlowManager[last_timeframe_idx_].timestamp;
        if ((uint64(block.timestamp) - mostRecentTimestamp_) > TIMEFRAMES_HOURLY_DAILY) {
            // cycle & move periods to the left
            for (uint256 i = 0; i < (DailyRewardsFlowManager.length - 1); i++) {
                DailyRewardsFlowManager[i] = DailyRewardsFlowManager[i + 1];
            }
            //update last timeframe with new values & reset counter
            DailyRewardsFlowManager[last_timeframe_idx_].timestamp = uint64(block.timestamp);
            DailyRewardsFlowManager[last_timeframe_idx_].counter = 0;
        }
    }

    /**
    * @notice Count the total EXD rewards on last hour
    */
    function getHourlyRewardsCount() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < HourlyRewardsFlowManager.length; i++) {
            total += HourlyRewardsFlowManager[i].counter;
        }
        return total;
    }

    /**
    * @notice Count the total EXD rewards on last day
    */
    function getDailyRewardsCount() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < DailyRewardsFlowManager.length; i++) {
            total += DailyRewardsFlowManager[i].counter;
        }
        return total;
    }


    // ---------- DEPOSIT  MECHANISMS ----------

    /**
    * @notice Deposit _numTokens ERC20 EXD tokens to fill the RewardsManager balance
    * This function will likely be called by the Exorde DAO and Exorde Labs
    * @param _numTokens The number of ERC20 tokens to deposit
    */
    function deposit(uint256 _numTokens) public {
        require(token.balanceOf(msg.sender) >= _numTokens, "RewardsManager: sender doesn't have enough tokens");
        // add the deposited tokens into existing balance
        ManagerBalance += _numTokens;

        // transfer the tokens from the sender to this contract
        require(
            token.transferFrom(msg.sender, address(this), _numTokens),
            "RewardsManager: error when depositing via TransferFrom"
        );
    }

    // ---------- WITHDRAWAL  MECHANISMS ----------

    /**
    * @notice Withdraw EXD rewards tokens associated to the user calling this function (the msg.sender)
    * @param _numTokens The number of ERC20 tokens to withdraw
    */
    function WithdrawRewards(uint256 _numTokens) external {
        require(
            ManagerBalance >= _numTokens,
            "RewardsManager: WithdrawRewards- require ManagerBalance >= _numTokens to withdraw"
        );
        rewards[msg.sender] -= _numTokens;
        require(token.transfer(msg.sender, _numTokens), "RewardsManager: WithdrawRewards- error transfering tokens");
    }

    /**
    * @notice Withdraw all rewards tokens associated to the user calling this function (the msg.sender)
    */
    function WithdrawAllRewards() external {
        require(
            ManagerBalance >= rewards[msg.sender],
            "RewardsManager: WithdrawAllRewards- require ManagerBalance >= _numTokens to withdraw"
        );
        uint256 all_rewards = rewards[msg.sender];
        rewards[msg.sender] = 0;
        require(
            token.transfer(msg.sender, all_rewards),
            "RewardsManager: WithdrawAllRewards- error transfering tokens"
        );
    }

    // ---------- OWNER MECHANISMS ----------
    /**
    * @notice Withdraw _numTokens ERC20 tokens from this rewards contracts
    *         Only callable by the owner
    * @param _numTokens The number of ERC20 tokens to withdraw
    */
    function OwnerWithdraw(uint256 _numTokens) external onlyOwner {
        require(ManagerBalance >= _numTokens, "ManagerBalance has to be >= _numTokens");
        ManagerBalance -= _numTokens;
        require(token.transfer(msg.sender, _numTokens), "Token Transfer failed");
    }

    /**
    * @notice returns the total amount of rewards distributed, during the life of this RewardsManager
    */
    function GetTotalGivenRewards() public view returns (uint256) {
        return TotalRewards;
    }

    /**
    * @notice Withdraw all rewards in the remaining pool from the Rewards Manager, to the contract owner
    * Usable in case of emergency or contract migration
    */
    function OwnerWithdrawAllRewards() external onlyOwner {
        require(ManagerBalance > 0, "ManagerBalance has to be > 0");
        uint256 sum = rewards[msg.sender];
        rewards[msg.sender] = 0;
        require(token.transfer(msg.sender, sum));
    }
    
    /**
    * @notice Withdraw (admin/owner only) any ERC20 (e.g. stuck on the contract)
    */
    function adminWithdrawERC20(IERC20 token_, address beneficiary_, uint256 tokenAmount_) external
    onlyOwner
    {
        token_.safeTransfer(beneficiary_, tokenAmount_);
    }
}
