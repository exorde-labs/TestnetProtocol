// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title StakeManager
 * @author Mathias Dail - Exorde Labs
 * @notice The StakeManager is a smart contract designed to manage staking, deposit, withdrawal, 
 *   and allocation of EXD tokens for users and whitelisted sub-systems. 
 *   This contract serves as the central staking manager and interacts with the sub-system contracts for locking or slashing stakes.
 * 
 * Key features and aspects of the contract logic:
 * - Centralized staking manager: Manages and oversees all staking activities within the ecosystem.
 * - Deposits and withdrawals: Allows users to deposit and withdraw EXD tokens from their free balance.
 * - Stakeholder management: Tracks the status of stakeholders and their stakes.
 * - Staking allocations: Allows the administrator (DAO/owner) to whitelist and remove contracts (sub-systems) that can allocate (lock) or slash stakes.
 * - Security and recovery: The administrator has the ability to remove faulty sub-systems, ensuring that user stakes are not lost and the staking system remains secure.
 * - Detailed information: Provides comprehensive information about stake allocations, total stakes, and stakeholder status for auditors and developers.
 * - Event logging: Emits relevant events for all major actions within the contract (e.g. deposits, withdrawals, stake allocations, slashing, etc.).
 * 
 * The StakeManager ensures that user stakes are not lost, even in the event of a faulty sub-system, 
 * by allowing the administrator to remove such sub-systems and recover the affected stakes.
 * 
 * @dev This contract uses the OpenZeppelin Ownable library to provide
 * ownership functionality, ensuring that certain functions can only be
 * called by the contract owner. SafeERC20 is used for IERC20 token transfers.
 */
contract StakingManager is
    Ownable {
    using SafeERC20 for IERC20;

    IERC20 public token;

    constructor(
        address EXD_token /*Avatar _avatar*/
    ) {
        token = IERC20(EXD_token);
    }

    address[] internal stakeholders;
    mapping(address => bool) public isStakeholderMap;


    struct TimeframeCounter {
        uint128 timestamp;
        uint128 counter;
    }

    mapping(address => mapping(address => uint256)) public UserStakeAllocations; // user -> system (contract) -> amount
    mapping(address => uint256) public TotalAllocationsPerSystem; // system (contract)  -> total system amount

    struct Balances {
        uint256 free_balance;
        uint256 staked_balance;
    }

    uint256 public TotalAvailableStake = 0;
    uint256 public TotalDeposited = 0;

    /**
     * Stakeholders account and balances
     */
    mapping(address => Balances) public balances;

    // ------------------------------------------------------------------------------------------
    // Contracts allowed to allocate stakes
    mapping(address => bool) private StakeWhitelistMap;
    address[] public StakeWhitelistedAddress;
    mapping(address => uint256) private StakeWhitelistedAddressIndex;

    // Contracts allowed to slash stakes
    mapping(address => bool) private StakeSlashingWhitelistMap;
    address[] public StakeSlashingWhitelistedAddress;
    mapping(address => uint256) private StakeSlashingWhitelistedAddressIndex;

    address slashedStakeSinkAddress;
    // addresses of schemes/contracts allowed to interact with stakes


    event AddedStakeholder(address indexed account);
    event RemovedStakeholder(address indexed account);
    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event Staked(address indexed account, uint256 amount);
    event AllocatedStake(address indexed account, uint256 amount);
    event DeallocatedStake(address indexed account, uint256 amount);
    event AdminWithdrawERC20(address indexed token_, address beneficiary_, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event SlashedOnSystemStake(address indexed account, address system, uint256 amount);
    event SlashedOnStakedBalance(address indexed account, uint256 amount);
    event StakeWhitelisted(address indexed account, bool isWhitelisted);
    event StakeUnWhitelisted(address indexed account, bool isWhitelisted);
    event StakeSlashingWhitelisted(address indexed account, bool isWhitelisted);
    event StakeSlashingUnWhitelisted(address indexed account, bool isWhitelisted);
    event SlashSinkUpdated(address indexed previous_account, address new_account);

    uint256 constant removed_index_value = 999999999;

    // -------
    /**
     * @notice Returns true if an address is whitelist for allocating user Stakes 
     * @param _address The address (contract, or user)
     */
    function isStakeWhitelisted(address _address) public view returns (bool) {
        return StakeWhitelistMap[_address];
    }

    /**
     * @notice Add a whitelisted address, allowed to interact with stakes (allocate them)
     * @param _address The address (contract, or user)
     */
    function addWhitelistedAddress(address _address) public onlyOwner {
        require(StakeWhitelistMap[_address] != true, "Address must not be whitelisted already");
        StakeWhitelistMap[_address] = true;
        StakeWhitelistedAddress.push(_address);
        StakeWhitelistedAddressIndex[_address] = StakeWhitelistedAddress.length - 1;
        emit StakeWhitelisted(_address, true);
    }

    /**
     * @notice Remove a whitelisted address, allowed to interact with stakes (allocate them)
     * @param _address The address (contract, or user)
     */
    function removeWhitelistedAddress(address _address) public onlyOwner {
        require(StakeWhitelistMap[_address] != false, "Address must be whitelisted already");
        StakeWhitelistMap[_address] = false;

        uint256 PrevIndex = StakeWhitelistedAddressIndex[_address];
        StakeWhitelistedAddressIndex[_address] = removed_index_value;

        StakeWhitelistedAddress[PrevIndex] = 
            StakeWhitelistedAddress[StakeWhitelistedAddress.length - 1]; // move last element
        StakeWhitelistedAddressIndex[StakeWhitelistedAddress[PrevIndex]] = PrevIndex;
        StakeWhitelistedAddress.pop();
        emit StakeUnWhitelisted(_address, false);
    }

    // -------
    /**
     * @notice Returns true if an address is whitelist for slashing stakes.
     * @param _address The address (contract, or user)
     */
    function isStakeSlashingWhitelisted(address _address) public view returns (bool) {
        return StakeSlashingWhitelistMap[_address];
    }

    /**
     * @notice Add a whitelisted address to the right to slash other addresses' stakes.
     * @param _address The address (contract, or user)
     */
    function addSlashingWhitelistedAddress(address _address) public onlyOwner {
        require(StakeSlashingWhitelistMap[_address] != true, "Address must not be whitelisted already");
        StakeSlashingWhitelistMap[_address] = true;
        StakeSlashingWhitelistedAddress.push(_address);
        StakeSlashingWhitelistedAddressIndex[_address] = StakeSlashingWhitelistedAddress.length - 1;
        emit StakeSlashingWhitelisted(_address, true);
    }

    /**
     * @notice Removes a whitelisted address from the right to slash other addresses' stakes.
     * @param _address The address (contract, or user)
     */
    function removeSlashingWhitelistedAddress(address _address) public onlyOwner {
        require(StakeSlashingWhitelistMap[_address] != false, "Address must be whitelisted already");
        StakeSlashingWhitelistMap[_address] = false;

        uint256 PrevIndex = StakeSlashingWhitelistedAddressIndex[_address];
        StakeSlashingWhitelistedAddressIndex[_address] = removed_index_value;

        StakeSlashingWhitelistedAddress[PrevIndex] = 
            StakeSlashingWhitelistedAddress[StakeSlashingWhitelistedAddress.length - 1]; // move last element
        StakeSlashingWhitelistedAddressIndex[StakeSlashingWhitelistedAddress[PrevIndex]] = PrevIndex;
        StakeSlashingWhitelistedAddress.pop();
        emit StakeSlashingUnWhitelisted(_address, false);
    }
    
    /**
     * @notice update the slashed stake sink address (receving slashed stakes)
     * @param _new_sink_address The new sink address
     */
    function updateSlashedSinkAddress(address _new_sink_address) public onlyOwner {
        address previous_address = slashedStakeSinkAddress;
        slashedStakeSinkAddress = _new_sink_address;
        emit SlashSinkUpdated(previous_address, _new_sink_address);
    }


    // ---------- STAKES ----------

    /**
     * @notice A method for a stakeholder to create a stake.
     * @param _stake The size of the stake to be created.
     */
    function Stake(uint256 _stake) public {
        require(balances[msg.sender].free_balance >= _stake, "deposited stake is too low");
        if (balances[msg.sender].staked_balance == 0){
            addStakeholder(msg.sender);
        }

        balances[msg.sender].free_balance -= _stake;
        balances[msg.sender].staked_balance += _stake;

        // Global state update
        TotalAvailableStake += _stake;
        emit Staked(msg.sender, _stake);
    }

    /**
     * @notice A method for a stakeholder to unstake _stake from its staked_balance
     * @param _stake The size of the stake to be unstaked and placed in free_balance.
     */
    function Unstake(uint256 _stake) public {
        require(balances[msg.sender].staked_balance >= _stake, "deposited stake is too low");

        balances[msg.sender].free_balance += _stake;
        balances[msg.sender].staked_balance -= _stake;

        // Global state update
        TotalAvailableStake -= _stake;
        if (balances[msg.sender].staked_balance == 0){
            removeStakeholder(msg.sender);
        }
        emit Unstaked(msg.sender, _stake);
    }

    /**
     * @notice A method for a stakeholder to close its (not locked) staked_balance 
     */
    function closeAllStakes() public {
        uint256 staked_amount = balances[msg.sender].staked_balance;
        balances[msg.sender].free_balance += staked_amount;
        balances[msg.sender].staked_balance -= staked_amount;

        // Global state update
        TotalAvailableStake -= staked_amount;
        removeStakeholder(msg.sender);
        emit Unstaked(msg.sender, staked_amount);
    }

    // ---------- EXTERNAL STAKE ALLOCATIONS ----------

    /**
     * @notice A method for a verified whitelisted contract to allocate for itself some stake
     * @param _StakeAllocation The amount to allocate
     * @param _stakeholder The address of the stakeholder
     */
    function ProxyStakeAllocate(uint256 _StakeAllocation, address _stakeholder) public returns (bool) {
        require(isStakeWhitelisted(msg.sender), "isStakeWhitelisted must be true for Sender");
        require(isStakeholder(_stakeholder), "isStakeholder must be true for Sender");
        require(
            balances[_stakeholder].staked_balance >= _StakeAllocation,
            "_stakeholder has to have enough staked balance"
        );
        // check if the contract calling this method has rights to allocate from user stake

        balances[_stakeholder].staked_balance -= _StakeAllocation;

        // Global state update
        UserStakeAllocations[_stakeholder][msg.sender] += _StakeAllocation;
        TotalAllocationsPerSystem[msg.sender]  += _StakeAllocation;

        emit AllocatedStake(_stakeholder, _StakeAllocation);
        return true;
    }

    /**
     * @notice A method for a verified whitelisted contract to deallocate stake from itself
     * _StakeToDeallocate has to be equal to the amount of at least one ALLOCATED allocation
     * else the procedure will fail.
     * @param _StakeToDeallocate The amount to deallocate
     * @param _stakeholder The address of the stakeholder
     */
    function ProxyStakeDeallocate(uint256 _StakeToDeallocate, address _stakeholder) public returns (bool) {
        // msg.sender is the sub-system calling this proxy function
        require(isStakeWhitelisted(msg.sender), "isStakeWhitelisted must be true for Sender");
        require(isStakeholder(_stakeholder), "isStakeholder must be true for Sender");
        require(
            UserStakeAllocations[_stakeholder][msg.sender] >= _StakeToDeallocate,
            "_stakeholder has to have enough allocated balance in this sub-system"
        );
        require(
            TotalAllocationsPerSystem[msg.sender] >= _StakeToDeallocate,
            "TotalAllocations in this sub-system is lower than _StakeToDeallocate"
        );

        balances[_stakeholder].staked_balance += _StakeToDeallocate;
        UserStakeAllocations[_stakeholder][msg.sender]  -= _StakeToDeallocate;            
        TotalAllocationsPerSystem[msg.sender]  -= _StakeToDeallocate;

        emit DeallocatedStake(_stakeholder, _StakeToDeallocate);
        return true;
    }

    /**
     * @notice A method for a verified whitelisted contract to slash _StakeToSlash
     * _StakeToSlash is either taken on the staked balance of the _stakeholder to slash, 
     * or from its allocated balance on _system_address
     * @param _StakeToSlash The amount to slash
     * @param _stakeholder The address of the stakeholder
     * @param _system_address The address of the system contract
     */
    function ProxyStakeSlash(uint256 _StakeToSlash, address _stakeholder, address _system_address) 
    public returns (bool) {
        require(_StakeToSlash > 0, " Stake to slash must be > 0");
        require(isStakeSlashingWhitelisted(msg.sender), "isStakeSlashingWhitelisted must be true for Sender");
        require(isStakeholder(_stakeholder), "isStakeholder must be true for Sender");
        bool has_slashed = false;
        // if a system was selected, slash allocation itself & send tokens to slashed pool
        if ( _system_address != address(0) && isStakeWhitelisted(_system_address) ){
            require(
                UserStakeAllocations[_stakeholder][_system_address] >= _StakeToSlash,
                "_stakeholder has to have enough allocated balance to slash in system"
            );
            require(
                TotalAllocationsPerSystem[_stakeholder] >= _StakeToSlash,
                "TotalAllocations in this sub-system is lower than _StakeToSlash"
            );
            UserStakeAllocations[_stakeholder][_system_address]  -= _StakeToSlash;
            TotalAllocationsPerSystem[_system_address]  -= _StakeToSlash;
            has_slashed = true;
            emit SlashedOnSystemStake(_stakeholder, _system_address, _StakeToSlash);
        }
        else{
            // else slash on staked_balance            
            require(balances[msg.sender].staked_balance >= _StakeToSlash, "Staked balance is too low to slash");
            balances[msg.sender].staked_balance -= _StakeToSlash;
            // Global state update
            TotalAvailableStake -= _StakeToSlash;
            has_slashed = true;
            if (balances[msg.sender].staked_balance == 0){
                removeStakeholder(msg.sender);
            }
            emit SlashedOnStakedBalance(_stakeholder, _StakeToSlash);
        }
        // send slashed tokens to slashed sink
        token.safeTransfer(slashedStakeSinkAddress, _StakeToSlash);
        return has_slashed;
    }

    // ---------- SUB-STAKE MANAGEMENT ----------

    /**
     * @notice gets the total amount of stakes allocated to a given sub system (a contract, e.g. a WorkSystem)
     * Allocated stakes are locked stakes, that are locked and unlocked according to the sub systems logic
     * @param _system The address of the system contract
     */
    function getSystemTotalAllocations(address _system) public view returns (uint256) {
        require(isStakeWhitelisted(_system), "_system must be whitelisted to have stake allocations");
        uint256 system_allocations_sum = 0;
        for(uint256 i = 0; i < StakeWhitelistedAddress.length; i++){
            address _sub_system = StakeWhitelistedAddress[i];
            // only whitelisted systems count in the total allocation
            // removing a system remove the allocations related to it
            if( StakeWhitelistMap[_sub_system] ){
                system_allocations_sum += TotalAllocationsPerSystem[_sub_system];
            }
        }
        return system_allocations_sum;
    }

    /**
     * @notice gets the total amount of stakes allocated, for a given user address
     * Allocated stakes are locked stakes, that are locked and unlocked according to the sub systems logic
     * @param _stakeholder The address of the user
     */
    function getUserTotalAllocation(address _stakeholder) public view returns (uint256) {
        uint256 user_allocations_sum = 0;
        for(uint256 i = 0; i < StakeWhitelistedAddress.length; i++){
            address _sub_system = StakeWhitelistedAddress[i];
            // only whitelisted systems count in the total allocation
            // removing a system remove the allocations related to it
            if( StakeWhitelistMap[_sub_system] ){
                user_allocations_sum += UserStakeAllocations[_stakeholder][_sub_system];
            }
        }
        return user_allocations_sum;
    }

    // ---------- STAKE STATS ----------

    /**
     * @notice A method to retrieve the stake for a stakeholder.
     * @param _stakeholder The stakeholder to retrieve the stake for.
     * @return uint256 The amount of wei staked.
     */
    function AvailableStakedAmountOf(address _stakeholder) public view returns (uint256) {
        return balances[_stakeholder].staked_balance;
    }

    /**
     * @notice A method to retrieve the stake for a stakeholder.
     * @param _stakeholder The stakeholder to retrieve the stake for.
     * @return uint256 The amount of wei staked.
     */
    function AllocatedStakedAmountOf(address _stakeholder) public view returns (uint256) {
        return getUserTotalAllocation(_stakeholder);
    }

    /**
     * @notice A method to the aggregated stakes from all stakeholders.
     * @return uint256 The aggregated stakes from all stakeholders.
     */
    function TotalStakes() public view returns (uint256) {
        return TotalAvailableStake;
    }

    /**
     * @notice A method to the aggregated stakes from all stakeholders.
     * @return uint256 The aggregated stakes from all stakeholders.
     */
    function TotalAllocatedStakes() public view returns (uint256) {
        uint256 _TotalAllocatedStake = 0;
        for(uint256 i = 0; i < StakeWhitelistedAddress.length; i++){
            address _sub_system = StakeWhitelistedAddress[i];
            // only whitelisted systems count in the total allocation
            // removing a system remove the allocations related to it
            if( StakeWhitelistMap[_sub_system] ){
                _TotalAllocatedStake += TotalAllocationsPerSystem[_sub_system];
            }
        }
        return _TotalAllocatedStake;

    }

    /**
     * @notice A method to the aggregated stakes from all stakeholders.
     * @return uint256 The aggregated stakes from all stakeholders.
     */
    function TotalDeposit() public view returns (uint256) {
        return TotalDeposited;
    }

    // ---------- STAKEHOLDERS ----------

    /**
     * @notice A method to check if an address is a stakeholder.
     * @param _address The address to verify.
     * @return bool, uint256 Whether the address is a stakeholder,
     * and if so its position in the stakeholders array.
     */
    function isStakeholder(address _address) public view returns (bool) {
        return isStakeholderMap[_address];
    }

    /**
     * @notice A method to add a stakeholder.
     * @param _stakeholder The stakeholder to add.
     */
    function addStakeholder(address _stakeholder) private {
        isStakeholderMap[_stakeholder] = true;
        emit AddedStakeholder(_stakeholder);
    }

    /**
     * @notice A method to remove a stakeholder.
     * @param _stakeholder The stakeholder to remove.
     */
    function removeStakeholder(address _stakeholder) private {
        isStakeholderMap[_stakeholder] = false;
        emit RemovedStakeholder(_stakeholder);
    }

    // ---------- DEPOSIT AND LOCKUP MECHANISMS ----------

    /**
    * @notice Deposit _numTokens ERC20 EXD tokens to the free balance of the msg.sender stakes
    * @param _numTokens The number of ERC20 tokens to deposit
    */
    function deposit(uint256 _numTokens) public {
        require(token.balanceOf(msg.sender) >= _numTokens, "not enough tokens to deposit");
        // add the deposited tokens into existing balance
        balances[msg.sender].free_balance += _numTokens;

        // transfer the tokens from the sender to this contract
        token.safeTransferFrom(msg.sender, address(this), _numTokens);
        emit Deposited(msg.sender, _numTokens);
    }

    /**
    * @notice Withdraw _numTokens ERC20 tokens from the free balance of the msg.sender stakes
    * @param _numTokens The number of ERC20 tokens to withdraw
    */
    function withdraw(uint256 _numTokens) public {
        // Check
        require(
            balances[msg.sender].free_balance >= _numTokens,
            "not enough tokens in the free staked balance to withdraw"
        );
        // Effect
        balances[msg.sender].free_balance -= _numTokens;
        // Interaction (token transfer)
        token.safeTransfer(msg.sender, _numTokens);
        emit Withdrawn(msg.sender, _numTokens);
    }

    /**
     * @notice Withdraw all available stakes (free balance)
     */
    function withdrawAll() public {
        // Check
        require(
            balances[msg.sender].free_balance > 0, 
            "not enough tokens to withdraw"
        );
        // Effect
        uint256 _AllTokens = balances[msg.sender].free_balance;
        balances[msg.sender].free_balance = 0;
        // Interaction (token transfer)
        token.safeTransfer(msg.sender, _AllTokens);
        emit Withdrawn(msg.sender, _AllTokens);
    }
    
    /**
    * @notice Withdraw (admin/owner only) any ERC20 (e.g. stuck on the contract)
    */
    function adminWithdrawERC20(IERC20 token_, address beneficiary_, uint256 tokenAmount_) external
    onlyOwner
    {
        token_.safeTransfer(beneficiary_, tokenAmount_);
        emit AdminWithdrawERC20(address(token_), beneficiary_, tokenAmount_);
    }
}