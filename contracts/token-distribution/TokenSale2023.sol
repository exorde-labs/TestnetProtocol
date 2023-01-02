// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with dollar. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conforms
 * the base architecture for crowdsales. It is *not* intended to be modified / overridden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropriate to concatenate
 * behavior.
 */
contract Crowdsale is Context, ReentrancyGuard, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // The token being sold
    IERC20 private _token;

    IERC20 public USDC;
    IERC20 public USDT;
    IERC20 public DAI;

    uint256 public USDC_decimal_count = 6;
    uint256 public USDT_decimal_count = 6;
    uint256 public DAI_decimal_count = 18;

    // Address where funds are collected
    address payable private _wallet;

    // How many token units a buyer gets per dollar.
    // The rate is the conversion between dollar and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 dollar will give you 1 unit, or 0.001 TOK.

    // The EXD Token Sale is Tiered
    //      Tier 1 = $0.35/EXD for the first 2 million (2 000 000) EXD tokens sold, then
    //      Tier 2 = $0.375/EXD for 4 million (4 000 000) EXD tokens sold, then
    //      Tier 3 = $0.40/EXD for the last 6 million (6 000 000) EXD tokens sold.
    // ------ Total EXD told (to be deposited in contract initially) = 12 000 000 EXD tokens. Twelve millions.
    // Requirements of the sale
    //      A. All buyers must be whitelisted by Exorde Labs, according to their KYC verification done on exorde.network
    //      B. All buyers are limited to $50k (50 000), 
    //          fifty thousand dollars of purchase, overall (they can buy multiple times).
    //      C. A tier ends when all tokens have been sold. 
    //      D. If token remain unsold after a period of 1 month, 
    //          the owner of the contract can withdraw the remaining tokens.
    //      E. Buyers get the EXD token instantly when buying.

    // price per tier, in dollar (divided by 1000)
    uint256 public _priceTier1 = 350; // $0.35, thirty five cents
    uint256 public _priceTier2 = 375; // $0.375, thirty five cents + half a cent
    uint256 public _priceTier3 = 400; // $0.4, fourty cents
    uint256 public _priceBase = 1000; // $0.4, fourty cents


   // You can only buy up to 12M tokens
    uint256 public maxTokensRaised = 12*(10**18); // 12 millions

    uint256 public _tier1SupplyThreshold = 2*(10**18); // 2 million at _rateTier1
    uint256 public _tier2SupplyThreshold = 6*(10**18); // 4 million at _rateTier2 (2m + 4m = 6m)
    uint256 public _tier3SupplyThreshold = 12*(10**18); // 6 million at _rateTier3  (2m + 4m + 6m = 12m = maxTokensRaised)

    uint256 public userMaxTotalPurchase = 50000; // 50000 dollars ($50k)

    uint256 public startTime;
    uint256 public endTime;

    // Amount of dollar raised
    uint256 public _dollarRaised;

    mapping(address => uint256) public _usersTotalPurchase;

    // Amount of token sold
    uint256 public totalTokensRaised;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value dollars paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    /// @notice Allow to extend ICO end date
    /// @param _endTime Endtime of ICO
    function setEndDate(uint256 _endTime)
        external onlyOwner whenNotPaused
    {
        require(block.timestamp <= _endTime);
        require(startTime < _endTime);
        
        endTime = _endTime;
    }

    
    /**
     * @dev The rate is the conversion between dollar and the smallest and indivisible
     * token unit. So, if you are using a rate of 1 with a ERC20Detailed token
     * with 3 decimals called TOK, 1 dollar will give you 1 unit, or 0.001 TOK.
     * @param wallet_ Address where collected funds will be forwarded to
     * @param token_ Address of the token being sold
     */
    constructor (address payable wallet_,  uint256 startTime_, uint256 endTime_, 
    IERC20 token_, IERC20 USDC_, IERC20 USDT_, IERC20 DAI_) {
        require(wallet_ != address(0), "Crowdsale: wallet is the zero address");
        require(address(token_) != address(0), "Crowdsale: token is the zero address");

        startTime = startTime_;
        endTime = endTime_;

        USDC = IERC20(USDC_);
        USDT = IERC20(USDT_);
        DAI = IERC20(DAI_);

        _wallet = wallet_;
        _token = token_;
    }

    //  ----------- WHITELISTING - KYC/AML -----------
        
    mapping(address => bool) public whitelist;

    /**
    * @dev Reverts if beneficiary is not whitelisted. Can be used when extending this contract.
    */
    modifier isWhitelisted(address _beneficiary) {
        require(whitelist[_beneficiary]);
        _;
    }

    /**
    * @dev Adds single address to whitelist.
    * @param _beneficiary Address to be added to the whitelist
    */
    function addToWhitelist(address _beneficiary) external onlyOwner {
        whitelist[_beneficiary] = true;
    }

    /**
    * @dev Adds list of addresses to whitelist. Not overloaded due to limitations with truffle testing.
    * @param _beneficiaries Addresses to be added to the whitelist
    */
    function addManyToWhitelist(address[] memory _beneficiaries) external onlyOwner {
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
        whitelist[_beneficiaries[i]] = true;
        }
    }

    /**
    * @dev Removes single address from whitelist.
    * @param _beneficiary Address to be removed to the whitelist
    */
    function removeFromWhitelist(address _beneficiary) external onlyOwner {
        whitelist[_beneficiary] = false;
    }

    //  ----------------------------------------------

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
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
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param purchaseAmount in dollar (usdc/usdt/dai)
     */
    function buyTokensUSDC(uint256 purchaseAmount) public 
    nonReentrant 
    whenNotPaused
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
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param purchaseAmount in dollar (usdc/usdt/dai)
     */
    function buyTokensUSDT(uint256 purchaseAmount) public 
    nonReentrant 
    whenNotPaused
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

        _forwardFunds(USDC, effectivePurchaseAmount);
        _postValidatePurchase(USDC, beneficiary, dollarsToRefund);
    }


    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param purchaseAmount in dollar (usdc/usdt/dai)
     */
    function buyTokensDAI(uint256 purchaseAmount) public 
    nonReentrant 
    whenNotPaused
    isWhitelisted( _msgSender()) 
    payable {
        address beneficiary = _msgSender();
        DAI.safeTransferFrom(_msgSender(), address(this), purchaseAmount);
        
        _preValidatePurchase(beneficiary, purchaseAmount);

        (uint256 tokens, uint256 dollarsToRefund) = _getTokenAmount(purchaseAmount);
        require( dollarsToRefund  <= purchaseAmount, "error: dollarsToRefund > purchaseAmount");
        uint256 effectivePurchaseAmount = purchaseAmount - dollarsToRefund;
        
        // update state
        _dollarRaised = _dollarRaised.add(effectivePurchaseAmount);

        _processPurchase(beneficiary, tokens);  
        emit TokensPurchased(_msgSender(), beneficiary, effectivePurchaseAmount, tokens);

        _updatePurchasingState(beneficiary, effectivePurchaseAmount);

        _forwardFunds(USDC, effectivePurchaseAmount);
        _postValidatePurchase(USDC, beneficiary, dollarsToRefund);
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
        // check if user total purchase is below the user cap.
        require( (_usersTotalPurchase[beneficiary]+dollarAmount) <= userMaxTotalPurchase, "total user purchase is capped at $50k" );
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

    // function _buyTokens(uint256 purchaseAmount) internal 
    // whenNotPaused 
    // {
    //   uint256 tokens = 0;      
    //   uint256 amountPaid = calculateExcessDollarBalance(purchaseAmount);

    //   if(totalTokensRaised < _tier1SupplyThreshold) {
    //      // Tier 1
    //      tokens = amountPaid.mul(_rateTier1);

    //      // If the amount of tokens that you want to buy gets out of this tier
    //      if(totalTokensRaised.add(tokens) > _tier1SupplyThreshold)
    //         tokens = calculateTokensToAllocate(amountPaid, 1);
    //   } else if(totalTokensRaised >= _tier1SupplyThreshold && totalTokensRaised < _tier2SupplyThreshold) {

    //      // Tier 2
    //      tokens = amountPaid.mul(_rateTier2);

    //      // If the amount of tokens that you want to buy gets out of this tier
    //      if(totalTokensRaised.add(tokens) > _tier1SupplyThreshold)
    //         tokens = calculateExcessTokens(amountPaid, 2);
    //   } else if(totalTokensRaised >= _tier2SupplyThreshold && totalTokensRaised < _tier3SupplyThreshold) {
    //      // Tier 3
    //      tokens = amountPaid.mul(_rateTier3);
    //   }

    //   _dollarRaised += amountPaid;
    //   uint256 tokensRaisedBeforeThisTransaction = totalTokensRaised;
    //   totalTokensRaised += tokens;
    //   token.distributeICOTokens(msg.sender, tokens);

    //   // Keep a record of how many tokens everybody gets in case we need to do refunds
    //   tokensBought[msg.sender] = tokensBought[msg.sender].add(tokens);
    //   TokenPurchase(msg.sender, amountPaid, tokens);

    //   if(tokensRaisedBeforeThisTransaction > minimumGoal) {

    //      walletB.transfer(amountPaid);

    //   } else {
    //      vault.deposit.value(amountPaid)(msg.sender);
    //      if(goalReached()) {
    //       vault.close();
    //      }
         
    //   }
    //   // If the minimum goal of the ICO has been reach, close the vault to send
    //   // the dollar to the wallet of the crowdsale
    //   checkCompletedCrowdsale();
    // }


   /// @notice Calculates how many dollar will be used to generate the tokens in
   /// case the buyer sends more than the maximum balance but has some balance left
   /// e.g. if 500 balance and user sends 1000, it will refund 500 dollars
    // function calculateExcessDollarBalance(uint256 purchaseAmount) view public returns(uint256) {
    //     uint256 amountPaid = purchaseAmount;
    //     uint256 differenceDollar = 0;
    //     // If we're in the last tier, check that the limit hasn't been reached
    //     // and if so, refund the difference and return what will be used to
    //     // buy the remaining tokens
    //     if(totalTokensRaised >= _tier3SupplyThreshold) {
    //         uint256 addedTokens = totalTokensRaised.add(amountPaid.mul(_rateTier3));
    //         // If totalTokensRaised + what you paid converted to tokens is bigger than the max
    //         if(addedTokens > maxTokensRaised) {
    //             // Refund the difference
    //             uint256 difference = addedTokens.sub(maxTokensRaised);
    //             differenceDollar = difference.div(_rateTier3);
    //             amountPaid = amountPaid.sub(differenceDollar);
    //         }
    //     }
    //     return amountPaid;
    // }
    

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


    function getCurrentTier() internal view returns (uint256) {
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


   /// @notice Calculate the token amount per tier function of dollarPaid in input
   /// @param dollarPaid_ The amount of dollar paid that will be used to buy tokens
   /// @param tierSelected_ The tier that you'll use for thir purchase
   /// @return calculatedTokens Returns how many tokens you've bought for that dollar paid
   function calculateTokensTier(uint256 dollarPaid_, uint256 tierSelected_) public 
   view returns(uint256){
      require(dollarPaid_ > 0);
      require(tierSelected_ >= 1 && tierSelected_ <= 3);
      uint256 calculatedTokens;

      if(tierSelected_ == 1){
         calculatedTokens = dollarPaid_.mul(_priceBase).div(_priceTier1);
      }
      else if(tierSelected_ == 2){
         calculatedTokens = dollarPaid_.mul(_priceBase).div(_priceTier2);
      }
      else{
         calculatedTokens = dollarPaid_.mul(_priceBase).div(_priceTier3);
      }

     return calculatedTokens;
   }


//    /// @notice Checks if a purchase is considered valid
//    /// @return bool If the purchase is valid or not
//    function validPurchase(uint256 purchaseAmount) internal  returns(bool) {
//       bool withinPeriod = now >= startTime && now <= endTime;
//       bool NoEthZeroPurchase = purchaseAmount == 0;
//       bool withinTokenLimit = totalTokensRaised < maxTokensRaised;
//       bool hasBalanceAvailable = crowdsaleBalances[purchaseAmount] < maxPurchase;

//       // We want to limit the gas to avoid giving priority to the biggest paying contributors
//       //bool limitGas = tx.gasprice <= limitGasPrice;

//       return withinPeriod && NoEthZeroPurchase && withinTokenLimit && hasBalanceAvailable;
//    }
   
//    /// @notice Public function to check if the crowdsale has ended or not
//    function hasEnded() public returns(bool) {
//       return now > endTime || totalTokensRaised >= maxTokensRaised;
//    }

    /// @notice Buys the tokens for the specified tier and for the next one
    /// @param dollarPurchaseAmount The amount of dollar paid to buy the tokens
    /// @return totalTokens The total amount of tokens bought combining the tier prices
    /// @return potential surplus to refund dollar amount
   function calculateTokensToAllocate(uint256 dollarPurchaseAmount) view public returns(uint256, uint256) {
        require(dollarPurchaseAmount > 0);
        uint256 allocatedTokens;
        uint256 surplusDollarsForNextTier = 0;
        uint256 surplusDollarsToRefund = 0;

        uint256 tierSelected = getCurrentTier();
        uint256 _currentTierSupplyLimit = getSupplyLimitPerTier(tierSelected);
        uint256 _currentRate = getPricePerTier(tierSelected);
        uint256 _tokensNextTier = 0;

        uint remainingTierDollars = ( _currentTierSupplyLimit - totalTokensRaised ) / _currentRate;
        // Check if there isn't enough dollars for the current Tier
        if ( dollarPurchaseAmount > remainingTierDollars ){
            surplusDollarsForNextTier = dollarPurchaseAmount - remainingTierDollars;
        }        
        if( surplusDollarsForNextTier > 0 ){
            // If there's excessive dollar for the last tier
            if(tierSelected != 3){ // if we are in Tier 1 or 2, then all dollars can be used
                _tokensNextTier = calculateTokensTier(surplusDollarsForNextTier, (tierSelected+1));
            }
            else{ // if we are in the last tier & have surplus, we have to refund this amount
                surplusDollarsToRefund = surplusDollarsForNextTier;
            }
        }
        // total Allocated Tokens = tokens for this tier + (optional) token for next tier
        allocatedTokens = (dollarPurchaseAmount - surplusDollarsForNextTier) + _tokensNextTier; 
        
        return (allocatedTokens, surplusDollarsToRefund);
   }

    /**
     * @dev Override to extend the way in which dollar is converted to tokens.
     * @param dollarAmount Value in dollar to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _dollarAmount
     * @return Dollar amount to refund (if any, can be zero)
     *  if in last Tier & not enough tokens to sell
     */
    function _getTokenAmount(uint256 dollarAmount) internal view returns (uint256, uint256) {
        return calculateTokensToAllocate(dollarAmount);
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
