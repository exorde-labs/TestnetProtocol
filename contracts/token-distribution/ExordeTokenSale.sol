// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

    /* 
    * ________________ Token Sale Setup __________________
        The EXD Token Sale is a 3-Tiered Dollar-based Token Sale
    *      Tier 1 = $0.33/EXD for the first 0.5 million (500 000) EXD tokens sold, then
    *      Tier 2 = $0.34/EXD for next 1.5 million (1 500 000) EXD tokens sold, then
    *      Tier 3 = $0.35/EXD for the last 10 million (10 000 000) EXD tokens sold.
    *   Total EXD sold (to be deposited in contract initially) = 12 000 000 EXD tokens. Twelve millions.
    * ________________ Requirements of the sale: __________________
    *      A. All buyers must be whitelisted by Exorde Labs, according to their KYC verification done on exorde.network
    *      B. All buyers are limited to $50k ($50 000), 
    *          fifty thousand dollars of purchase, overall (they can buy multiple times).
    *      C. A tier ends when all tokens have been sold. 
    *      D. If tokens remain unsold after the sale, 
    *          the owner of the contract can withdraw the remaining tokens.
    *      E. Buyers get the EXD token instantly when buying.
    * ________________ Contract Administration __________________
    *      A. When paused/ended, the owner can withdraw any ERC20 tokens from the contract
    *      B. The owner can pause the contract in case of emergency
    *      C. The end time can be extended at will by the owner
    */

contract ExordeTokenSale is Context, ReentrancyGuard, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event AddressWhitelisted(address indexed user);
    event AddressDeWhitelisted(address indexed user);

    // The EXD ERC20 token being sold
    // Predeployed & deposited in this contract after deployment
    IERC20 private _token; 

    IERC20 public USDC;
    IERC20 public USDT;
    IERC20 public DAI;

    uint256 public constant USDC_decimal_count = 6;
    uint256 public constant USDT_decimal_count = 6;
    uint256 public constant DAI_decimal_count = 18;

    uint256 private constant THOUSAND = 10**3;
    uint256 private constant MILLION = 10**6;
    uint256 private constant EXD_DECIMAL_COUNT = 10**18;
    
    // price per tier, in dollar (divided by 1000)
    uint256 public _priceBase = 1000*(10**12);
    uint256 public _priceTier1 = 330; // $0.33
    uint256 public _priceTier2 = 340; // $0.34
    uint256 public _priceTier3 = 350; // $0.35

   // You can only buy up to 12M tokens
    uint256 public maxTokensRaised       =    12 * MILLION  * EXD_DECIMAL_COUNT;            // 12 millions EXD (12 000 000 EXD) maximum to sell

   // tiers supply threshold (cumulative): tier 2 threshold is tier 1 supply + tier 2 supply
    uint256 public _tier1SupplyThreshold =   500 * THOUSAND * EXD_DECIMAL_COUNT;            // first 500k EXD (500 000 EXD)
    uint256 public _tier2SupplyThreshold =     2 * MILLION  * EXD_DECIMAL_COUNT;            // then 1.5m EXD (1 500 000 EXD) + previous tokens
    uint256 public _tier3SupplyThreshold =    12 * MILLION  * EXD_DECIMAL_COUNT;            // last threshold is amount to the max Tokens Raised

   // An individual is capped to $50k
    uint256 public userMaxTotalPurchase = 50 * THOUSAND * (10**6); // 50000 dollars ($50k) in USDC 6 decimals base

    uint256 public startTime;
    uint256 public endTime;
    uint256 private immutable OneWeekDuration = 60*60*24*7; //in seconds, 1 week = 60*60*24*7 = 604800

    // Amount of dollar raised
    uint256 public _dollarRaised;
    
    // Users state
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public _usersTotalPurchase;

    // Amount of token sold
    uint256 public totalTokensRaised;

    // Address where funds are collected
    address payable private _wallet;

    // Address where funds are collected
    address private whitelister_wallet;

    /*
    * @dev Constructor setting up the sale
    * @param wallet_ which will receive the funds from the buyers (e.g. a multi sig vault)
    * @param startTime_ (timestamp) date of start of the token sale
    * @param endTime_ (timestamp) date of end of the token sale (can be extended)
    */
    constructor (address payable wallet_,  uint256 startTime_, uint256 endTime_, 
    IERC20 token_, IERC20 USDC_, IERC20 USDT_, IERC20 DAI_) {
        require(wallet_ != address(0), "Crowdsale: wallet is the zero address");
        require(address(token_) != address(0), "Crowdsale: token is the zero address");
        require(startTime_ < endTime_ && endTime_ > block.timestamp, "start & end time are incorrect");
        startTime = startTime_;
        endTime = endTime_;

        USDC = IERC20(USDC_);
        USDT = IERC20(USDT_);
        DAI = IERC20(DAI_);

        _wallet = wallet_;
        _token = token_;
    }

    //  ----------- WHITELISTING - KYC/AML -----------

    /**
    * @dev Updates the whitelister_wallet, only address allowed to add/remove from whitelist
    * @param new_whitelister_wallet Address to become the new whitelister_wallet 
    */
    function adminUpdateWhitelisterAddress(address new_whitelister_wallet) public onlyOwner {
        require(new_whitelister_wallet != address(0), "new whitelister address must be non zero");
        whitelister_wallet = new_whitelister_wallet;
    }

    /**
    * @dev Reverts if beneficiary is not whitelisted. Can be used when extending this contract.
    */
    modifier isWhitelisted(address _beneficiary) {
        require(whitelist[_beneficiary],"user not whitelisted");
        _;
    }

    /**
    * @dev Adds single address to whitelist.
    * @param _beneficiary Address to be added to the whitelist
    */
    function addToWhitelist(address _beneficiary) external {
        require(msg.sender == whitelister_wallet, "sender is not allowed to modify whitelist");
        whitelist[_beneficiary] = true;
        emit AddressWhitelisted(_beneficiary);
    }

    /**
    * @dev Adds list of addresses to whitelist. Not overloaded due to limitations with truffle testing.
    * @param _beneficiaries Addresses to be added to the whitelist
    */
    function addManyToWhitelist(address[] memory _beneficiaries) external {
        require(msg.sender == whitelister_wallet, "sender is not allowed to modify whitelist");
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            whitelist[_beneficiaries[i]] = true;
            emit AddressDeWhitelisted(_beneficiaries[i]);
        }
    }

    /**
    * @dev Removes single address from whitelist.
    * @param _beneficiary Address to be removed to the whitelist
    */
    function removeFromWhitelist(address _beneficiary) external {
        require(msg.sender == whitelister_wallet, "sender is not allowed to modify whitelist");
        whitelist[_beneficiary] = false;
        emit AddressDeWhitelisted(_beneficiary);
    }

    //  ----------- ADMIN - END -----------

    /**
    * @notice Withdraw (admin/owner only) any unsold Exorde tokens or other ERC20 stuck on the contract
    */
    function adminWithdrawERC20(IERC20 token_, address beneficiary_, uint256 tokenAmount_) external
    onlyOwner
    isInactive
    MinimumTimeLock
    {
        token_.safeTransfer(beneficiary_, tokenAmount_);
    }
    
    /**
   * @notice Pause or unpause the contract
  */
    function toggleSystemPause() public onlyOwner {        
        if(paused()){
            _unpause();
        }else{
            _pause();
        }
    }

    //  ----------------------------------------------
    /**
    * @notice Allow to extend Sale end date
    * @param _endTime Endtime of Sale
    */
    function setEndDate(uint256 _endTime)
        external 
        onlyOwner 
        MinimumTimeLock
    {
        require(block.timestamp < _endTime, "new endTime must > now");
        endTime = _endTime;
    }

    /**
    * @dev Reverts if sale has not started or has ended
    */
    modifier isSaleOpen() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "the sale is not open");
        _;
    }

    /**
    * @dev Reverts if 1 week has not passed since the start of the Public Sale
    */
    modifier MinimumTimeLock() {        
        require(block.timestamp > startTime + OneWeekDuration, "Owner must wait at least 1 week after Sale start to update");
        _;
    }
    /**
    * @dev Returns if the Token Sale is active (started & not ended)
    * @return the boolean indicating if the sale is active (true : active)
    */
    function isOpen() public view returns (bool){
        return block.timestamp >= startTime && block.timestamp <= endTime;
    }
    
    /**
    * @dev Reverts if Sale is Inactive (paused or closed)
    */
    modifier isInactive() {
        require( !isOpen(), "the sale is active" );
        _;
    }
    
    /**
    * @dev fallback to reject non zero ETH transactions
    */
    receive () external payable {
        revert("ETH not authorized, please use buyTokens()");
    }

    /**
     * @return the token being sold.
     */
    function token() public view returns (IERC20) {
        return _token;
    }

    /**
     * @return the address where funds are collected.
     */
    function wallet() public view returns (address payable) {
        return _wallet;
    }


    /**
     * @return the amount of dollar raised.
     */
    function dollarRaised() public view returns (uint256) {
        return _dollarRaised;
    }

    /**
     * @dev Token Purchase Function, using USDC on Ethereum, with 6 decimals
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param purchaseAmount in dollar (usdc/usdt/dai)
     */
    function buyTokensUSDC(uint256 purchaseAmount) public 
    nonReentrant 
    whenNotPaused
    isSaleOpen
    isWhitelisted(_msgSender()) 
    {
        address beneficiary = _msgSender();
        USDC.safeTransferFrom(beneficiary, address(this), purchaseAmount);
        
        _preValidatePurchase(beneficiary, purchaseAmount);

        (uint256 tokens, uint256 dollarsToRefund) = _getTokenAmount(purchaseAmount);

        require( dollarsToRefund  <= purchaseAmount, "error: dollarsToRefund > purchaseAmount");
        uint256 effectivePurchaseAmount = purchaseAmount - dollarsToRefund;
        
        // update state
        _dollarRaised = _dollarRaised.add(effectivePurchaseAmount);

        _processPurchase(beneficiary, tokens);  
        emit TokensPurchased(beneficiary, beneficiary, effectivePurchaseAmount, tokens);

        _updatePurchasingState(beneficiary, effectivePurchaseAmount);

        _forwardFunds(USDC, effectivePurchaseAmount);
        _postValidatePurchase(USDC, beneficiary, dollarsToRefund);
    }


    /**
     * @dev Token Purchase Function, using USDT (Tether) on Ethereum, with 6 decimals
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param purchaseAmount in dollar (usdc/usdt/dai)
     */
    function buyTokensUSDT(uint256 purchaseAmount) public 
    nonReentrant 
    whenNotPaused
    isSaleOpen
    isWhitelisted( _msgSender()) 
    {
        address beneficiary = _msgSender();
        USDT.safeTransferFrom(beneficiary, address(this), purchaseAmount);
        
        _preValidatePurchase(beneficiary, purchaseAmount);

        (uint256 tokens, uint256 dollarsToRefund) = _getTokenAmount(purchaseAmount);
        require( dollarsToRefund  <= purchaseAmount, "error: dollarsToRefund > purchaseAmount");
        uint256 effectivePurchaseAmount = purchaseAmount - dollarsToRefund;
        
        // update state
        _dollarRaised = _dollarRaised.add(effectivePurchaseAmount);

        _processPurchase(beneficiary, tokens);  
        emit TokensPurchased(_msgSender(), beneficiary, effectivePurchaseAmount, tokens);

        _updatePurchasingState(beneficiary, effectivePurchaseAmount);

        _forwardFunds(USDT, effectivePurchaseAmount);
        _postValidatePurchase(USDT, beneficiary, dollarsToRefund);
    }


    /**
     * @dev Token Purchase Function, using DAI on Ethereum, with 18 decimals
     * The user who calls this needs to have previously approved (approve()) purchaseAmount_ on the DAI contract
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param purchaseAmount_ in dollar (usdc/usdt/dai)
     */
    function buyTokensDAI(uint256 purchaseAmount_) public 
    nonReentrant 
    whenNotPaused
    isSaleOpen
    isWhitelisted( _msgSender()) 
    {
        address beneficiary = _msgSender();
        DAI.safeTransferFrom(_msgSender(), address(this), purchaseAmount_);
        uint256 purchaseAmount = purchaseAmount_.div(10**12); //DAI has 12 more digits than USDC/UST
        
        _preValidatePurchase(beneficiary, purchaseAmount);

        (uint256 tokens, uint256 dollarsToRefund) = _getTokenAmount(purchaseAmount);
        require( dollarsToRefund  <= purchaseAmount, "error: dollarsToRefund > purchaseAmount");
        uint256 effectivePurchaseAmount = purchaseAmount - dollarsToRefund;
        
        // update state
        _dollarRaised = _dollarRaised.add(effectivePurchaseAmount);

        _processPurchase(beneficiary, tokens);  
        emit TokensPurchased(_msgSender(), beneficiary, effectivePurchaseAmount, tokens);

        _updatePurchasingState(beneficiary, effectivePurchaseAmount);

        _forwardFunds(DAI, effectivePurchaseAmount);
        _postValidatePurchase(DAI, beneficiary, dollarsToRefund);
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * Use `super` in contracts that inherit from Crowdsale to extend their validations.
     * Example from CappedCrowdsale.sol's _preValidatePurchase method:
     *     super._preValidatePurchase(beneficiary, dollarAmount);
     *     require(dollarRaised().add(dollarAmount) <= cap);
     * @param beneficiary Address performing the token purchase
     * @param dollarAmount Value in dollar involved in the purchase
     */
    function _preValidatePurchase(address beneficiary, uint256 dollarAmount) internal view virtual {
        require(beneficiary != address(0), "Crowdsale: beneficiary is the zero address");
        require(dollarAmount != 0, "Crowdsale: dollarAmount is 0");
        require(totalTokensRaised < maxTokensRaised, "Crowdsale is now sold out");
        // check if user total purchase is below the user cap.
        require( (_usersTotalPurchase[beneficiary]+dollarAmount) <= userMaxTotalPurchase, 
        "total user purchase is capped at $50k" );
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid
     * conditions are not met.
     * @param beneficiary Address performing the token purchase
     * @param toRefundAmount Value in dollar to be refunded
     */
    function _postValidatePurchase(IERC20 inputToken_, address beneficiary, uint256 toRefundAmount) internal {
        if( toRefundAmount > 0){
            _refundDollars(inputToken_, beneficiary, toRefundAmount);
        }
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends
     * its tokens.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal virtual {
        _token.safeTransfer(beneficiary, tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
     * tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal virtual {
        _deliverTokens(beneficiary, tokenAmount);
        totalTokensRaised += tokenAmount;
    }

    /**
     * @dev Override for extensions that require an internal state to check for validity (current user contributions,
     * etc.)
     * @param beneficiary Address receiving the tokens
     * @param dollarAmount Value in dollar involved in the purchase
     */
    function _updatePurchasingState(address beneficiary, uint256 dollarAmount) internal virtual {
        _usersTotalPurchase[beneficiary] += dollarAmount;
    }

    /**
     * @notice Returns the supply limit threshold of tierSelected_
     * @param tierSelected_ The tier (1, 2 or 3)
     * @return supplyLimit of the Tier, in EXD, with 18 decimals
     */
    function getSupplyLimitPerTier(uint256 tierSelected_) public view returns (uint256) {
        require(tierSelected_ >= 1 && tierSelected_ <= 3);
        uint256 _supplyLmit;
        if( tierSelected_ == 1 ){
            _supplyLmit = _tier1SupplyThreshold;
        }
        else if( tierSelected_ == 2 ){            
            _supplyLmit = _tier2SupplyThreshold;
        }
        else if( tierSelected_ == 3 ){            
            _supplyLmit = _tier3SupplyThreshold;
        }
        return _supplyLmit;
    }

    /**
     * @notice Returns the price of tierSelected_
     * @param tierSelected_ The tier (1, 2 or 3)
     * @return price price of the tier, in dollar (with 6 decimals for USDC & USDT)
     */
    function getPricePerTier(uint256 tierSelected_) public view returns (uint256) {
        require(tierSelected_ >= 1 && tierSelected_ <= 3);
        uint256 _price;
        if( tierSelected_ == 1 ){
            _price = _priceTier1;
        }
        else if( tierSelected_ == 2 ){            
            _price = _priceTier2;
        }
        else if( tierSelected_ == 3 ){            
            _price = _priceTier3;
        }
        return _price;
    }


    /**
     * @notice Return the current Tier (between 1, 2 or 3)
     * @return Tier current Tier
     */
    function getCurrentTier() public view returns (uint256) {
        uint256 _currentTier;
        // if tokenRaised is > threshold2, then we are in Tier 3
        if( totalTokensRaised > _tier2SupplyThreshold ){
            _currentTier = 3;
        // Else, if tokenRaised is > threshold1, then we are in Tier 2
        }else if( totalTokensRaised > _tier1SupplyThreshold ){
            _currentTier = 2;
        }
        // Else, we are by default in Tier 1
        else{
            _currentTier = 1;
        }

        return _currentTier;
    }


    /**
     * @notice Calculate the token amount per tier function of dollarPaid in input
     * @param dollarPaid_ The amount of dollar paid that will be used to buy tokens
     * @param tierSelected_ The tier that you'll use for thir purchase
     * @return calculatedTokens Returns how many tokens you've bought for that dollar paid
     */
   function calculateTokensTier(uint256 dollarPaid_, uint256 tierSelected_) public 
   view returns(uint256){
      require(tierSelected_ >= 1 && tierSelected_ <= 3);
      uint256 calculatedTokens;

      if(tierSelected_ == 1){
         calculatedTokens = dollarPaid_.div(_priceTier1).mul(_priceBase);
      }
      else if(tierSelected_ == 2){
         calculatedTokens = dollarPaid_.div(_priceTier2).mul(_priceBase);
      }
      else{
         calculatedTokens = dollarPaid_.div(_priceTier3).mul(_priceBase);
      }

     return calculatedTokens;
   }

    /**
     * @notice Remaining number of dollars (>= 0) left in the current Tier of the Sale
     */
   function remainingTierDollars() public 
   view returns(uint256){
        uint256 tierSelected = getCurrentTier();
        uint256 remainingTierTokens_ = getSupplyLimitPerTier(tierSelected) - totalTokensRaised;
        uint256 remainingTierDollarPurchase_ = remainingTierTokens_.mul(getPricePerTier(tierSelected)).div(_priceBase);
        return remainingTierDollarPurchase_;
   }

    /**
     * @notice Buys the tokens for the specified tier and for the next one
     * @param dollarPurchaseAmount The amount of dollar paid to buy the tokens
     * @return totalTokens The total amount of tokens bought combining the tier prices
     * @return surplusTokens A potentially non-zero surplus of dollars to refund
     */
   function _getTokenAmount(uint256 dollarPurchaseAmount) view public returns(uint256, uint256) {
        require(dollarPurchaseAmount > 0);
        uint256 allocatedTokens = 0;
        uint256 surplusDollarsForNextTier = 0;
        uint256 surplusDollarsToRefund = 0;

        uint256 _currentTier = getCurrentTier();
        uint256 _tokensNextTier = 0;

        uint256 remainingTierDollarPurchase = remainingTierDollars();
        // Check if there isn't enough dollars for the current Tier
        if ( dollarPurchaseAmount > remainingTierDollarPurchase ){
            surplusDollarsForNextTier = dollarPurchaseAmount - remainingTierDollarPurchase;
        }
        if( surplusDollarsForNextTier > 0 ){
            // If there's excessive dollar for the last tier
            if(_currentTier <= 2){ // if we are in Tier 1 or 2, then all dollars can be used
                _tokensNextTier = calculateTokensTier(surplusDollarsForNextTier, (_currentTier + 1) );
            }
            else{ // if we are in the last tier & have surplus, we have to refund this amount
                surplusDollarsToRefund = surplusDollarsForNextTier;
            }
            // total Allocated Tokens = tokens for this tier + token for next tier
            allocatedTokens = calculateTokensTier((dollarPurchaseAmount - surplusDollarsForNextTier), _currentTier) 
                              + _tokensNextTier; 
        }
        else{
            allocatedTokens = calculateTokensTier(dollarPurchaseAmount, _currentTier);
        }
        
        return (allocatedTokens, surplusDollarsToRefund);
   }

    /**
     * @dev Determines how funds are stored/forwarded on purchases.
     */
    function _forwardFunds(IERC20 inputToken_, uint256 amount_) internal virtual {
        inputToken_.safeTransfer( _wallet, amount_  );
    }

    /**
     * @dev Determines how funds are stored/forwarded on purchases.
     */
    function _refundDollars(IERC20 inputToken_, address beneficiary,  uint256 amount_) internal  {
        inputToken_.safeTransfer( beneficiary , amount_  );
    }
}
