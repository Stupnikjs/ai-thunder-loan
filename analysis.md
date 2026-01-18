# CODE ANALYSIS 



## PRECISION 

### 
 
asset has some exchange rate and start at 1e18
exchange rate is supposed to increase after each deposit 


```solidity 

// in ThunderLoan
function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        // first call its 1e18
        uint256 exchangeRate = assetToken.getExchangeRate();
        // here if amount has no minimum and amount is small 
        // mint amount can be 0 here 
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);

        uint256 calculatedFee = getCalculatedFee(token, amount);
        assetToken.updateExchangeRate(calculatedFee);
        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }

 function getCalculatedFee(IERC20 token, uint256 amount) public view returns (uint256 fee) {
        // price precision must be 1e18 at least same than s_feePrecision 
        // might append require( price_Precision / s_feePrecision > 100, "fee_precision must be lower than price precision")
        uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
        // if valueOfBorrowed token < s_feePrecision / s_flashLoanFee ===> fees = 0 
        fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;
    }

```
fees calculated for small deposit will be 0, so updateExchangeRate will revert
might only accept deposit from somme amount here > s_feePrecision / s_flashLoanFee




## REEDEM FUNC 

### 


```solidity 

   /// @notice Withdraws the underlying token from the asset token
    /// @param token The token they want to withdraw from
    /// @param amountOfAssetToken The amount of the underlying they want to withdraw
    function redeem(
        IERC20 token,
        uint256 amountOfAssetToken
    )
        external
        revertIfZero(amountOfAssetToken)
        revertIfNotAllowedToken(token)
    {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        if (amountOfAssetToken == type(uint256).max) {
            amountOfAssetToken = assetToken.balanceOf(msg.sender);
        }
        uint256 amountUnderlying = (amountOfAssetToken * exchangeRate) / assetToken.EXCHANGE_RATE_PRECISION();
        emit Redeemed(msg.sender, token, amountOfAssetToken, amountUnderlying);
        assetToken.burn(msg.sender, amountOfAssetToken);
        // needs approve to safeTransferFrom
        assetToken.transferUnderlyingTo(msg.sender, amountUnderlying);
    }
```