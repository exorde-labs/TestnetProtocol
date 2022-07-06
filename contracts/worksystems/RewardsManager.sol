// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;



import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface IAddressManager {
    function isSenderMasterOf(address _address) external returns (bool);
    function isSenderSubOf(address _master) external returns (bool);
    function isSubAddress(address _master, address _address) external returns (bool);
    function addAddress(address _address) external;
    function removeAddress(address _address) external;
}


contract RewardsManager is Ownable{
    event UserRegistered(bytes32 name, uint256 timestamp);
    event UserTransferred(bytes32 name);
    using SafeMath for uint;


    IAddressManager public AddressManager;    
    IERC20 public token;    
    mapping(address => uint256) public rewards; // maps user's address to voteToken balance
    uint256 public ManagerBalance = 0;
    uint256 TotalRewards = 0;


    constructor(address EXD_token /*Avatar _avatar*/)  {
        token =  IERC20(EXD_token);
    }

    
    // ------------------------------------------------------------------------------------------

    mapping (address => bool) private RewardsWhitelistMap; 
    // addresses of schemes/contracts allowed to interact with Rewardss


    event RewardsWhitelisted(address indexed account, bool isWhitelisted);
    event RewardsUnWhitelisted(address indexed account, bool isWhitelisted);

    function isRewardsWhitelisted(address _address)
        public
        view
        returns (bool)
    {
        return RewardsWhitelistMap[_address];
    }
    


    function addAddress(address _address)
        public
        onlyOwner
    {
        require(RewardsWhitelistMap[_address] != true, "RewardsManager: address must not be whitelisted already");
        RewardsWhitelistMap[_address] = true;
        emit RewardsWhitelisted(_address, true);
    }

    function removeAddress(address _address)
        public
        onlyOwner
    {        
        require(RewardsWhitelistMap[_address] != false, "RewardsManager: address must be whitelisted to remove");
        RewardsWhitelistMap[_address] = false;
        emit RewardsUnWhitelisted(_address, false);        
    }

    function updateAddressManager(address addr)
    public
    onlyOwner
    {
        AddressManager  = IAddressManager(addr);
    }
    
    
    // ---------- EXTERNAL Rewards ALLOCATIONS ----------
    
    
    /**
     * @notice A method for a verified whitelisted contract to allocate for itself some Rewards // nonReentrant()
     */
    function ProxyAddReward(uint256 _RewardsAllocation, address _user) 
        external
        returns(bool)
    {
        require(isRewardsWhitelisted(msg.sender), "RewardsManager: sender must be whitelisted to Proxy act");
        // require(ManagerBalance >=  _RewardsAllocation);
        require(_RewardsAllocation >  0, "rewards to allocate must be positive..");
        // check if the contract calling this method has rights to allocate from user Rewards
        if(ManagerBalance >=  _RewardsAllocation){
            ManagerBalance = ManagerBalance.sub(_RewardsAllocation);
            rewards[_user] = rewards[_user].add(_RewardsAllocation);
            TotalRewards = TotalRewards.add(_RewardsAllocation);
            return true;
        }
        return(false);
    }
    
    function RewardsBalanceOf(address _address)
        public
        view
        returns (uint256)
    {
        return rewards[_address];
    }
    
    
    // ---------- ----------
    
    /**
     * @notice A method for a verified whitelisted contract to allocate for itself some Rewards
     */
    function OwnerAddRewards(uint256 rep, address _user)
        public
        onlyOwner
    {
        rewards[_user] = rewards[_user].add(rep);
    }
    
    
    /**
     * @notice A method for a verified whitelisted contract to allocate for itself some Rewards
     */
    function OwnerRemoveRewards(uint256 rep, address _user)
        public
        onlyOwner
    {
        rewards[_user] = rewards[_user].sub(rep);
    }
    
    
    function OwnerResetRewards(address _user)
        public
        onlyOwner
    {
        rewards[_user] = 0;
    }
    
    
    // ---------- DEPOSIT  MECHANISMS ----------

        
    function deposit(uint _numTokens) public {
        require(token.balanceOf(msg.sender) >= _numTokens, "RewardsManager: sender doesn't have enough tokens");
        // add the deposited tokens into existing balance 
        ManagerBalance += _numTokens;

        // transfer the tokens from the sender to this contract
        require(token.transferFrom(msg.sender, address(this), _numTokens), "RewardsManager: error when depositing via TransferFrom");
    }

     
    // ---------- WITHDRAWAL  MECHANISMS ----------

        
    function WithdrawRewards(uint _numTokens) external {
        require(ManagerBalance >= _numTokens, "RewardsManager: WithdrawRewards- require ManagerBalance >= _numTokens to withdraw");
        rewards[msg.sender] -= _numTokens;
        require(token.transfer(msg.sender, _numTokens), "RewardsManager: WithdrawRewards- error transfering tokens");
    }

    function WithdrawAllRewards() external {
        require(ManagerBalance >= rewards[msg.sender], "RewardsManager: WithdrawAllRewards- require ManagerBalance >= _numTokens to withdraw");
        uint256 all_rewards = rewards[msg.sender];
        rewards[msg.sender] = 0;
        require(token.transfer(msg.sender, all_rewards), "RewardsManager: WithdrawAllRewards- error transfering tokens");
    }
    
       
    function WithdrawSubworker(uint _numTokens, address _worker) external {
        require(address(AddressManager) != address(0)); // check if AddressManager is set
        require(ManagerBalance >= _numTokens);
        require(AddressManager.isSubAddress(msg.sender, _worker)); //1st is supposed master, 2nd is sub address
        rewards[_worker] -= _numTokens;
        require(token.transfer(msg.sender, _numTokens));
    }

    function withdrawSubworkerAllRewards(address _worker) external {
        require(address(AddressManager) != address(0)); // check if AddressManager is set
        require(ManagerBalance >= rewards[_worker]);
        require(AddressManager.isSubAddress(msg.sender, _worker)); //1st is supposed master, 2nd is sub address
        uint256 all_rewards = rewards[msg.sender];
        rewards[msg.sender] = 0;
        require(token.transfer(msg.sender, all_rewards));
    }

    // ---------- OWNER RARE MECHANISMS ----------


    /**
    @notice Withdraw _numTokens ERC20 tokens from the voting contract, revoking these voting rights
    @param _numTokens The number of ERC20 tokens desired in exchange for voting rights
    */
    function OwnerWithdraw(uint _numTokens) external onlyOwner {
        require(ManagerBalance >= _numTokens);
        ManagerBalance -= _numTokens;
        require(token.transfer(msg.sender, _numTokens));
    }
    
    function GetTotalGivenRewards() public view returns(uint256) {
        return TotalRewards;
    }

    
    /**
    @notice Withdraw _numTokens ERC20 tokens from the voting contract, revoking these voting rights
    */
    function OwnerWithdrawAllRewards() external onlyOwner {
        require(ManagerBalance > 0);
        uint256 sum = rewards[msg.sender];
        rewards[msg.sender] = 0;
        require(token.transfer(msg.sender, sum));
    }
    
}