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
    mapping(address => uint256) public rewards; // maps user's address to voteToken balance
    uint256 public ManagerBalance = 0;
    uint256 TotalRewards = 0;
    IParametersManager public Parameters;

    struct TimeframeCounter {
        uint128 timestamp;
        uint128 counter;
    }

    // Cap rewards at 30k EXD per 24 hours, and 1.25k per hour
    uint16 constant NB_TIMEFRAMES_HOURLY = 15;
    uint16 constant TIMEFRAMES_HOURLY_DURATION = 240; // 240*15 = 3600s = 1 hour
    uint16 constant NB_TIMEFRAMES_DAILY = 24;
    uint16 constant TIMEFRAMES_HOURLY_DAILY = 3600; // 3600*24 = 1 day
    TimeframeCounter[NB_TIMEFRAMES_HOURLY] public HourlyRewardsFlowManager;
    TimeframeCounter[NB_TIMEFRAMES_DAILY] public DailyRewardsFlowManager;
    
    constructor(
        address EXD_token
    ) {
        token = IERC20(EXD_token);
    }

    function updateParametersManager(address addr) public onlyOwner {
        require(addr != address(0));
        Parameters = IParametersManager(addr);
    }

    // ------------------------------------------------------------------------------------------

    mapping(address => bool) private RewardsWhitelistMap;
    // addresses of schemes/contracts allowed to interact with Rewardss

    event RewardsWhitelisted(address indexed account, bool isWhitelisted);
    event RewardsUnWhitelisted(address indexed account, bool isWhitelisted);

    function isRewardsWhitelisted(address _address) public view returns (bool) {
        return RewardsWhitelistMap[_address];
    }

    function addAddress(address _address) public onlyOwner {
        require(RewardsWhitelistMap[_address] != true, "RewardsManager: address must not be whitelisted already");
        RewardsWhitelistMap[_address] = true;
        emit RewardsWhitelisted(_address, true);
    }

    function removeAddress(address _address) public onlyOwner {
        require(RewardsWhitelistMap[_address] != false, "RewardsManager: address must be whitelisted to remove");
        RewardsWhitelistMap[_address] = false;
        emit RewardsUnWhitelisted(_address, false);
    }

    // ---------- EXTERNAL Rewards ALLOCATIONS ----------

    /**
     * @notice A method for a verified whitelisted contract to allocate for itself some Rewards // nonReentrant()
     */
    function ProxyAddReward(uint256 _RewardsAllocation, address _user) external returns (bool) {
        require(isRewardsWhitelisted(msg.sender), "RewardsManager: sender must be whitelisted to Proxy act");
        // require(ManagerBalance >=  _RewardsAllocation);
        require(_RewardsAllocation > 0, "rewards to allocate must be positive..");
        // check if the contract calling this method has rights to allocate from user Rewards
        if (ManagerBalance >= _RewardsAllocation) {
            ManagerBalance -= _RewardsAllocation;
            rewards[_user] +=  _RewardsAllocation;
            TotalRewards += _RewardsAllocation;
            return true;
        }
        return (false);
    }

    /**
     * @notice A method for a verified whitelisted contract to transferRewards // nonReentrant()
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


    function RewardsBalanceOf(address _address) public view returns (uint256) {
        return rewards[_address];
    }

    // ---------- ----------

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


    // ---------------------

    /**
     * @notice A method for a verified whitelisted contract to allocate for itself some Rewards
     */
    function OwnerAddRewards(uint256 rep, address _user) public onlyOwner {
        rewards[_user] += rep;
    }

    /**
     * @notice A method for a verified whitelisted contract to allocate for itself some Rewards
     */
    function OwnerRemoveRewards(uint256 rep, address _user) public onlyOwner {
        require(rewards[_user] >= rep, "can't substract more rewards that user has");
        rewards[_user] -= rep;
    }

    function OwnerResetRewards(address _user) public onlyOwner {
        rewards[_user] = 0;
    }

    // ---------- DEPOSIT  MECHANISMS ----------

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

    function WithdrawRewards(uint256 _numTokens) external {
        require(
            ManagerBalance >= _numTokens,
            "RewardsManager: WithdrawRewards- require ManagerBalance >= _numTokens to withdraw"
        );
        rewards[msg.sender] -= _numTokens;
        require(token.transfer(msg.sender, _numTokens), "RewardsManager: WithdrawRewards- error transfering tokens");
    }

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

    function WithdrawSubworker(uint256 _numTokens, address _worker) external {
        require(Parameters.getAddressManager() != address(0), "AddressManager is null in Parameters");
        IAddressManager _AddressManager = IAddressManager(Parameters.getAddressManager());
        require(ManagerBalance >= _numTokens, "ManagerBalance has to be >= _numTokens");
        require(_AddressManager.isSubAddress(msg.sender, _worker)); //1st is supposed master, 2nd is sub address
        rewards[_worker] -= _numTokens;
        require(token.transfer(msg.sender, _numTokens), "Token Transfer failed");
    }

    function withdrawSubworkerAllRewards(address _worker) external {
        require(Parameters.getAddressManager() != address(0), "AddressManager is null in Parameters");
        IAddressManager _AddressManager = IAddressManager(Parameters.getAddressManager());
        require(ManagerBalance >= rewards[_worker], "ManagerBalance has to be >= worker rewards");
        require(_AddressManager.isSubAddress(msg.sender, _worker)); //1st is supposed master, 2nd is sub address
        uint256 all_rewards = rewards[msg.sender];
        rewards[msg.sender] = 0;
        require(token.transfer(msg.sender, all_rewards), "Token Transfer failed");
    }

    // ---------- OWNER RARE MECHANISMS ----------

    /**
    @notice Withdraw _numTokens ERC20 tokens from the voting contract, revoking these voting rights
    @param _numTokens The number of ERC20 tokens desired in exchange for voting rights
    */
    function OwnerWithdraw(uint256 _numTokens) external onlyOwner {
        require(ManagerBalance >= _numTokens, "ManagerBalance has to be >= _numTokens");
        ManagerBalance -= _numTokens;
        require(token.transfer(msg.sender, _numTokens), "Token Transfer failed");
    }

    function GetTotalGivenRewards() public view returns (uint256) {
        return TotalRewards;
    }

    /**
    @notice Withdraw _numTokens ERC20 tokens from the voting contract, revoking these voting rights
    */
    function OwnerWithdrawAllRewards() external onlyOwner {
        require(ManagerBalance > 0, "ManagerBalance has to be > 0");
        uint256 sum = rewards[msg.sender];
        rewards[msg.sender] = 0;
        require(token.transfer(msg.sender, sum));
    }
}
