// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract StakingManager is
    Ownable {

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

    event StakeWhitelisted(address indexed account, bool isWhitelisted);
    event StakeUnWhitelisted(address indexed account, bool isWhitelisted);
    event StakeSlashingWhitelisted(address indexed account, bool isWhitelisted);
    event StakeSlashingUnWhitelisted(address indexed account, bool isWhitelisted);

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

        StakeWhitelistedAddress[PrevIndex] = StakeWhitelistedAddress[StakeWhitelistedAddress.length - 1]; // move last element
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

        StakeSlashingWhitelistedAddress[PrevIndex] = StakeSlashingWhitelistedAddress[StakeSlashingWhitelistedAddress.length - 1]; // move last element
        StakeSlashingWhitelistedAddressIndex[StakeSlashingWhitelistedAddress[PrevIndex]] = PrevIndex;
        StakeSlashingWhitelistedAddress.pop();
        emit StakeSlashingUnWhitelisted(_address, false);
    }
    
    // -------
    // update the slashed stake sink address (receving slashed stakes)
    function updateSlashedSinkAddress(address _address) public onlyOwner {
        slashedStakeSinkAddress = _address;
    }


    // ---------- STAKES ----------

    /**
     * @notice A method for a stakeholder to create a stake.
     * @param _stake The size of the stake to be created.
     */
    function Stake(uint256 _stake) public {
        require(balances[msg.sender].free_balance >= _stake, "deposited stake is too low");
        if (balances[msg.sender].staked_balance == 0) addStakeholder(msg.sender);

        balances[msg.sender].free_balance -= _stake;
        balances[msg.sender].staked_balance += _stake;

        // Global state update
        TotalAvailableStake += _stake;
    }

    /**
     * @notice A method for a stakeholder to close all available stakes
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
    }

    /**
     * @notice A method for a stakeholder to close all available stakes
     */
    function closeAllStakes() public {
        uint256 staked_amount = balances[msg.sender].staked_balance;
        balances[msg.sender].free_balance += staked_amount;
        balances[msg.sender].staked_balance -= staked_amount;

        // Global state update
        TotalAvailableStake -= staked_amount;
        removeStakeholder(msg.sender);
    }

    // ---------- EXTERNAL STAKE ALLOCATIONS ----------

    /**
     * @notice A method for a verified whitelisted contract to allocate for itself some stake // nonReentrant()
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

        return (true);
    }

    /**
     * @notice A method for a verified whitelisted contract to allocate for itself some stake
     * _StakeToDeallocate has to be equal to the amount of at least one ALLOCATED allocation
     * else the procedure will fail
     */
    function ProxyStakeDeallocate(uint256 _StakeToDeallocate, address _stakeholder) public returns (bool) {
        require(isStakeWhitelisted(msg.sender), "isStakeWhitelisted must be true for Sender");
        require(isStakeholder(_stakeholder), "isStakeholder must be true for Sender");
        require(
            UserStakeAllocations[_stakeholder][msg.sender] >= _StakeToDeallocate,
            "_stakeholder has to have enough allocated balance in this sub-system"
        );

        balances[_stakeholder].staked_balance += _StakeToDeallocate;

        if ( UserStakeAllocations[_stakeholder][msg.sender] >= _StakeToDeallocate ){
            UserStakeAllocations[_stakeholder][msg.sender]  -= _StakeToDeallocate;            
        }
        if ( TotalAllocationsPerSystem[msg.sender] >= _StakeToDeallocate ){
            TotalAllocationsPerSystem[msg.sender]  -= _StakeToDeallocate;            
        }
        return (true);
    }

    /**
     * @notice A method for a verified whitelisted contract to allocate for itself some stake
     * _StakeToDeallocate has to be equal to the amount of at least one ALLOCATED allocation
     * else the procedure will fail
     */
    function ProxyStakeSlash(uint256 _StakeToSlash, address _stakeholder, address _system_address) public returns (bool) {
        require(_StakeToSlash > 0, " Stake to slash must be > 0");
        require(isStakeSlashingWhitelisted(msg.sender), "isStakeSlashingWhitelisted must be true for Sender");
        require(isStakeholder(_stakeholder), "isStakeholder must be true for Sender");
        // if a system was selected, slash allocation itself & send tokens to slashed pool
        if ( _system_address != address(0) && isStakeWhitelisted(_system_address) ){
            uint256 _allocatedUserSystemStake = UserStakeAllocations[_stakeholder][_system_address];   
            require(
                _allocatedUserSystemStake >= _StakeToSlash,
                "_stakeholder has to have enough allocated balance to slash in system"
            );
            if ( UserStakeAllocations[_stakeholder][_system_address] >= _StakeToSlash ){
                UserStakeAllocations[_stakeholder][_system_address]  -= _StakeToSlash;            
            }
            if ( TotalAllocationsPerSystem[_system_address] >= _StakeToSlash ){
                TotalAllocationsPerSystem[_system_address]  -= _StakeToSlash;            
            }

        }
        else{
            // else slash on staked_balance            
            require(balances[msg.sender].staked_balance >= _StakeToSlash, "Staked balance is too low to slash");
            balances[msg.sender].staked_balance -= _StakeToSlash;
            // Global state update
            TotalAvailableStake -= _StakeToSlash;
            if (balances[msg.sender].staked_balance == 0){
                removeStakeholder(msg.sender);
            }
        }
        // send slashed tokens to slashed sink
        require(token.transfer(slashedStakeSinkAddress, _StakeToSlash), "_StakeToSlash Token transfer failed");
        return (true);
    }

    // ---------- SUB-STAKE MANAGEMENT ----------

    /**
     * @notice A method for a stakeholder to close all available stakes
     */
    function AdminUserDeallocate(uint256 _StakeToDeallocate, address _stakeholder) public onlyOwner {
        require(balances[_stakeholder].staked_balance >= _StakeToDeallocate, "deposited stake is too low");
        // Global state update
        if ( UserStakeAllocations[_stakeholder][msg.sender] >= _StakeToDeallocate ){
            UserStakeAllocations[_stakeholder][msg.sender]  -= _StakeToDeallocate;            
        }
        if ( TotalAllocationsPerSystem[msg.sender] >= _StakeToDeallocate ){
            TotalAllocationsPerSystem[msg.sender]  -= _StakeToDeallocate;            
        }
        balances[_stakeholder].staked_balance += _StakeToDeallocate;
    }

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
    }

    /**
     * @notice A method to remove a stakeholder.
     * @param _stakeholder The stakeholder to remove.
     */
    function removeStakeholder(address _stakeholder) private {
        isStakeholderMap[_stakeholder] = false;
    }

    // ---------- DEPOSIT AND LOCKUP MECHANISMS ----------

    /**
    * @notice Deposit _numTokens ERC20 EXD tokens to the free balance of the msg.sender stakes
    * @param _numTokens The number of ERC20 tokens to deposit
    */
    function deposit(uint256 tokens) public {
        require(token.balanceOf(msg.sender) >= tokens, "not enough tokens to deposit");
        // add the deposited tokens into existing balance
        balances[msg.sender].free_balance += tokens;

        // transfer the tokens from the sender to this contract
        require(token.transferFrom(msg.sender, address(this), tokens), "Token transfer failed");
    }

    /**
    * @notice Withdraw _numTokens ERC20 tokens from the free balance of the msg.sender stakes
    * @param _numTokens The number of ERC20 tokens to withdraw
    */
    function withdraw(uint256 _numTokens) public {
        require(
            balances[msg.sender].free_balance >= _numTokens,
            "not enough tokens in the free staked balance to withdraw"
        );
        require(token.transfer(msg.sender, _numTokens), "Token transfer failed");
        balances[msg.sender].free_balance -= _numTokens;
    }

    /**
     * @notice Withdraw all available stakes (free balance)
     */
    function withdrawAll() public {
        require(balances[msg.sender].free_balance > 0, "not enough tokens to withdraw");
        require(token.transfer(msg.sender, balances[msg.sender].free_balance), "Token transfer failed");
        balances[msg.sender].free_balance = 0;
    }
}
