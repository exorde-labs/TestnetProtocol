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
    mapping(address => mapping(address => uint256)) public SystemsUserAllocations; // user -> worksystem -> amount

    struct Balances {
        uint256 free_balance;
        uint256 staked_balance;
        uint256 allocated_balance;
    }

    uint256 public TotalAvailableStake = 0;
    uint256 public TotalAllocatedStake = 0;
    uint256 public TotalDeposited = 0;

    /**
     * Stakeholders account and balances
     */
    mapping(address => Balances) public balances;

    // ------------------------------------------------------------------------------------------

    mapping(address => bool) private StakeWhitelistMap;
    address[] public StakeWhitelistedAddress;
    mapping(address => uint256) private StakeWhitelistedAddressIndex;
    // addresses of schemes/contracts allowed to interact with stakes

    event StakeWhitelisted(address indexed account, bool isWhitelisted);
    event StakeUnWhitelisted(address indexed account, bool isWhitelisted);

    function isStakeWhitelisted(address _address) public view returns (bool) {
        return StakeWhitelistMap[_address];
    }

    function addAddress(address _address) public onlyOwner {
        require(StakeWhitelistMap[_address] != true, "Address must not be whitelisted already");
        StakeWhitelistMap[_address] = true;
        StakeWhitelistedAddress.push(_address);
        StakeWhitelistedAddressIndex[_address] = StakeWhitelistedAddress.length - 1;
        emit StakeWhitelisted(_address, true);
    }

    function removeAddress(address _address) public onlyOwner {
        require(StakeWhitelistMap[_address] != false, "Address must be whitelisted already");
        StakeWhitelistMap[_address] = false;

        uint256 PrevIndex = StakeWhitelistedAddressIndex[_address];
        StakeWhitelistedAddressIndex[_address] = 999999999;

        StakeWhitelistedAddress[PrevIndex] = StakeWhitelistedAddress[StakeWhitelistedAddress.length - 1]; // move last element
        StakeWhitelistedAddressIndex[StakeWhitelistedAddress[PrevIndex]] = PrevIndex;
        StakeWhitelistedAddress.pop();

        emit StakeUnWhitelisted(_address, false);
    }

    // ---------- STAKES ----------

    /**
     * @notice A method for a stakeholder to create a stake.
     * @param _stake The size of the stake to be created.
     */
    function Stake(uint256 _stake) public {
        require(balances[msg.sender].free_balance >= _stake);
        if (balances[msg.sender].staked_balance == 0) addStakeholder(msg.sender);

        balances[msg.sender].free_balance -= _stake;
        balances[msg.sender].staked_balance += _stake;

        // Global state update
        TotalAvailableStake += _stake;
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
        balances[_stakeholder].allocated_balance += _StakeAllocation;

        SystemsUserAllocations[_stakeholder][msg.sender] += _StakeAllocation;

        // Global state update
        TotalAllocatedStake += _StakeAllocation;
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
            balances[_stakeholder].allocated_balance >= _StakeToDeallocate,
            "_stakeholder has to have enough allocated balance"
        );
        // check if the contract calling this method has rights to allocate from user stake

        balances[_stakeholder].allocated_balance -= _StakeToDeallocate;
        balances[_stakeholder].staked_balance += _StakeToDeallocate;

        SystemsUserAllocations[_stakeholder][msg.sender] -= _StakeToDeallocate;
        // Global state update
        TotalAllocatedStake -= _StakeToDeallocate;
        return (true);
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
        return balances[_stakeholder].allocated_balance;
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
        return TotalAllocatedStake;
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

    function deposit(uint256 tokens) public {
        require(token.balanceOf(msg.sender) >= tokens, "not enough tokens to deposit");
        // add the deposited tokens into existing balance
        balances[msg.sender].free_balance += tokens;

        // transfer the tokens from the sender to this contract
        require(token.transferFrom(msg.sender, address(this), tokens), "Token transfer failed");
    }

    /**
    @notice Withdraw _numTokens ERC20 tokens from the voting contract, revoking these voting rights
    @param _numTokens The number of ERC20 tokens desired in exchange for voting rights
    */
    function withdraw(uint256 _numTokens) public {
        require(
            balances[msg.sender].free_balance >= _numTokens,
            "not enough tokens in the free staked balance to withdraw"
        );
        require(token.transfer(msg.sender, _numTokens), "Token transfer failed");
        balances[msg.sender].free_balance -= _numTokens;
    }

    function withdrawAll() public {
        require(balances[msg.sender].free_balance > 0, "not enough tokens to withdraw");
        require(token.transfer(msg.sender, balances[msg.sender].free_balance), "Token transfer failed");
        balances[msg.sender].free_balance = 0;
    }
}
