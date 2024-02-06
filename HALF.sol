// SPDX-License-Identifier: UNLICENCED

//////////////////////////////////////////
//                                      //
//   ██╗  ██╗ █████╗ ██╗     ███████╗   //
//   ██║  ██║██╔══██╗██║     ██╔════╝   //
//   ███████║███████║██║     █████╗     //   
//   ██╔══██║██╔══██║██║     ██╔══╝     // 
//   ██║  ██║██║  ██║███████╗██║        //
//                                      //
//////////////////////////////////////////

// HALF Token (halftoken.xyz) is a novel concept where you cannot ever sell 
// more than 50% of your tokens in any SINGLE TRANSACTION. The transaction 
// will revert if you attempt to sell more than 50% at once.

// For example, if you had 1000 HALF tokens in your wallet, and attempt to 
// sell more than 500 tokens to the DEX, then the transaction will either 
// revert, produce an error, or simply not allow you to proceed.

// If you did sell 500 tokens (50%), then you'd be left with 500 HALF in your 
// wallet, which means for your next sell, you wouldn't be able to sell more 
// than 250 HALF tokens, and so on.

// Benefits: HALF massively reduces sell pressure. You would need to generate 
// multiple transactions to sell large numbers. The mechanism also stops bots 
// instantly trying to dump tokens after a price spike. Also, the number of 
// "token holders" never goes down, because you cannot ever sell 100% of your
// holdings in a single transaction. This allows for steady price movement.

//////////////////////     Important notes:     ////////////////////////////// 

// HALF is designed to work with all UniswapV2 clones that support "fee-on-transfer".
// Also, the transfer (and transferFrom) functions are unable to distinguish 
// between a "sell" (swap) on a DEX and the process of adding liquidity, as both 
// processes involve the recipient of tokens being a DEX, therefor, the limitation 
// of sending 50% of your stash to a liquidity pool also applies.

// Note that the following trnasactions have NO LIMITS:
// 1. Wallet-to-Wallet transfers
// 2. BUYING HALF tokens from the DEX
// 3. Removing Liquidity from the DEX

// For more information visit https://halftoken.xyz 
// or our Telegram group: https://t.me/halftoken

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/release-v4.9/contracts/token/ERC20/IERC20Upgradeable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/release-v4.9/contracts/access/OwnableUpgradeable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/release-v4.9/contracts/proxy/utils/Initializable.sol";


/// @title An ERC20 contract named HALF
/// @author HalfToken developer team (info@halftoken.xyz)
/// @notice Serves as a dynamic reflection token
/// @dev Inherits multiple OpenZeppelin standards 
contract HALF is Initializable, IERC20Upgradeable, OwnableUpgradeable {

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /// array of address which are excluded from rewards
    address[] public _excluded;

    /// maps an address to an amount owned in tSpace
    mapping(address => uint256) private _tOwned;
    /// maps an address to an amount owned in rSpace
    mapping(address => uint256) private _rOwned;
    
    /**
    /// maps an owner to a spender, and the amount of tokens that the spender is 
    /// approved to spend on behalf of the owner. Used in the custom _approve function 
    */
    mapping(address => mapping(address => uint256)) private _allowances;

    /// maps addresses to whether they are excluded from Fees/Rewards or not
    mapping(address => bool) private _isExcluded;

    /// maps addresses to whether they are excluded from the Max Tx or not
    mapping(address => bool) private _isExcludedFromMaxTx;

    /// fixed value representing MAX which is 2**256-1
    uint256 private _MAX;

    /// @notice the total fixed supply of STAIK tokens
    uint256 public _tTotal;

    /**
    /// rTotal is a calculated value - rTotal = MAX − (MAX mod tTotal)
    /// (Note: value will go down after each buy/sell transaction)  
    */
    uint256 public _rTotal;

    /// maximum transation amount
    uint256 public maxTxAmount;

    /////////////////////////////////////////////////////////////
    ////                                                     ////
    ////    Initializer - part of upgradeable ERC20 token    ////
    ////                                                     ////
    /////////////////////////////////////////////////////////////

    function initialize(
        // bool initialTestingFunctionsAllowed

        ) initializer external {


        /// ownableUpgradeble call __Ownable_init function
        OwnableUpgradeable.__Ownable_init();

        /// sets token details
        _name = "STEST2";
        _symbol = "STEST2";
        _decimals = 18;

        /// total token supply is assigned to _tTotal, expressed in wei (10 Billion)
        _tTotal = 10000000000000000000000000000;

        // /// used for rSpace
        _MAX = ~uint256(0);

        /// rTotal calculated based on tTotal
        _rTotal = (_MAX - (_MAX % _tTotal));

        /// adds the rTotal value to owner array mapping which effectively gives owner initial supply
        _rOwned[owner()] = _rTotal;

         maxTxAmount = _tTotal;


        /// exclude These contracts from fees and rewards
        _isExcluded[address(0)] = true;
        _isExcluded[address(0x000000000000000000000000000000000000dEaD)] = true;

        /// exclude These contracts from maxTxAmount
        _isExcluded[address(0)] = true;
        _isExcluded[address(0x000000000000000000000000000000000000dEaD)] = true;

        emit Transfer(address(0), owner(), _tTotal);
        
    }

    ////////    ERC20 Token functions    ////////

    /// @notice token name
    function name() public view returns (string memory) {
        return _name;
    }

    /// @notice token symbol
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /// @notice token decimals
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /// @notice uses "override" to return value from _tTotal (tSpace)
    function totalSupply() public view override (IERC20Upgradeable) returns (uint256) {
        return _tTotal;
    }

    /// @notice uses "override" - returns tOwned amounts for excluded addresses and rOwned amounts for all others
    function balanceOf(address account) public view override (IERC20Upgradeable) returns (uint256) {
        // if account is excluded, return balance in tSpace
        if (_isExcluded[account]) {
            return _tOwned[account];
        } else {
            // if account is NOT excluded, return balance in rSpace
            return rBalanceOf(account);
        }
    }

    /// @notice uses "override" to call the _transfer function
    function transfer(address recipient, uint256 amount) public override (IERC20Upgradeable) returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /// @notice uses "override" and calls the  _transfer and the _approve functions
    function transferFrom(
        address sender, 
        address recipient, 
        uint256 amount
        ) 
        public override (IERC20Upgradeable) returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    /// @notice uses "override" and returns the value from the _allowances function
    function allowance(address owner, address spender) public view override (IERC20Upgradeable) returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @notice uses "override" and returns the custom _approve function
    function approve(address spender, uint256 amount) public override (IERC20Upgradeable) returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /// @notice uses "override" and calls the _approve function
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /// @notice uses "override" and calls the _approve function
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    /////////////////////////////////////////////////////
    ////    HALF token-specific custom Functions     ////
    /////////////////////////////////////////////////////

    /**
    /// @notice checks if address is DEX-related smart contract
    */
    bytes4 private constant SELECTOR = bytes4(keccak256("factory()"));

    function isRouter(address _address) internal view returns (bool) {
        (bool success, bytes memory data) = _address.staticcall(abi.encodeWithSelector(SELECTOR));
        return success && data.length > 0;
    }

    /**
    /// @notice as address as being excluded from Max Tx (usually DEX)
    /// IMPORTANT: once an address is marked excluded it becomes PERMANENTLY excluded
    */
    function excludeFromMaxTx(address account) private {
        require(!_isExcludedFromMaxTx[account], "Account is already excluded");
        _isExcludedFromMaxTx[account] = true;
    }

    /**
    /// @notice marks an address as being excluded from rewards (usually DEX)
    /// and then adds the address the excluded address array
    /// IMPORTANT: once an address is marked excluded it becomes PERMANENTLY excluded
    */
    function excludeAddress(address account) private {
        require(!_isExcluded[account], "Account is already excluded");

        /// if address is not a null address..
        if (_rOwned[account] > 0) {
            /// then set tOwned value for account to be value based on 
            /// caling the rBalanceOf() function
            _tOwned[account] = rBalanceOf(account);
        }

        /// also set address as excluded
        _isExcluded[account] = true;
        /// also add address to the array of excluded addresses
        _excluded.push(account);
    }

    /**
    /// @notice Used by the standard ERC20 "balanceOf()" function
    /// returns the rAmount divided by the current rate value. 
    */
    function rBalanceOf(address account) public view returns (uint256) {
        uint256 rOwned = _rOwned[account];
        
        /// first check that rOwned balance is less than the rTotal
        require(rOwned <= _rTotal, "Amount must be less than total reflections");
        /// set the currentRate value from the _getRate function
        uint256 currentRate = _getRate();
        if (rOwned == 0) {
            return 0;
        } else {
            /// displays the rOwned amount expressed in tSpace
            return rOwned / currentRate;
        }
    }


    /// @notice function used by the getValues function
    function _getRate() public view returns (uint256) {
        /// retrieve values from _getCurrentSupply function
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        /// rsupply divided by tsupply
        return rSupply / tSupply;
    }

    /// @notice used by the _getRate function to return two values: rSupply and tSupply
    function _getCurrentSupply() public view returns (uint256, uint256) {
        /// firstly set the values to _rTotal and _tTotal
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;

        /// loop for each excluded address:          
        for (uint256 i = 0; i < _excluded.length; i++) {
            /// set rSupply to be rSupply minus excluded _rOwned value        
            rSupply = rSupply - _rOwned[_excluded[i]];
            /// set tSupply to be tSupply minus excluded _tOwned value    
            tSupply = tSupply - _tOwned[_excluded[i]];
        }

        return (rSupply, tSupply);
    }

    /// @notice CUSTOM approve function to override ERC20 approve function
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {

        /// check that owner and spender are not 0 addresses
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        /// adds the amount to the owner->spender _allowances mapping
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    bool private mutex = false;

    /// @notice CUSTOM transfer function to override ERC20 transfer function
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {

        // re-entrancy protection
        require(mutex == false);
        mutex = true;

        /// checks all inputs are greater than 0
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        /// checks if the "from" address or the "to" address is a V2 Router
        /// If it is, and it's not already in the  _isExcluded and _isExcludedFromMaxTx arrays,
        /// then it should be added.

        if (
            isRouter(from) == true && 
            !_isExcludedFromMaxTx[from] &&
            !_isExcluded[from]
            ) {
                excludeFromMaxTx(from);
                excludeAddress(from);
        }

        if (
            isRouter(to) == true && 
            !_isExcludedFromMaxTx[to] &&
            !_isExcluded[to]
            ) {
                excludeFromMaxTx(to);
                excludeAddress(to);
        }

        /// checks if contract owner is either the "from" or the "to" address
        if (from != owner() && to != owner()) {
            /**
            /// assuming neither addresses are owner, 
            /// then if the from AND to addresses are NOT excluded from MAX Tx
            */
            if (!_isExcludedFromMaxTx[from] && !_isExcludedFromMaxTx[to]) {
                /// check amount is less than maxTxAmount
                require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
            }
        }

        /// checks if from AND to addresses are NOT owner
        if (from != owner() && to != owner()) {
            /**
            /// assuming neither addresses are owner...
            /// then if the from and to addresses are not excluded
            */
            if (!_isExcludedFromMaxTx[from] && !_isExcludedFromMaxTx[to]) {
                /// check amount is less than maxTxAmount
                require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
            }
        }

        /**
        /// transfer amount, by calling the _tokenTransfer function. It will also pass in takeFee boolean
        /// (part of custom "_transfer" function)
        */    
        _tokenTransfer(from, to, amount);

        mutex = false;
    }


    /// @notice CUSTOM token transfer function called by _transfer()
    function _tokenTransfer(address sender, address recipient, uint256 amount) private {

        /// SENDER EXCLUDED ADDRESS - (Token buy)
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
             _transferFromExcluded(sender, recipient, amount);


        ///////////////////////////////////////////////////////////////////
        /// RECEIVER EXCLUDED ADDRESS - (Token sell)
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        ///////////////////////////////////////////////////////////////////


        /// BOTH SENDER AND RECEIVER ARE EXCLUDED ADDRESSES
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
             _transferBothExcluded(sender, recipient, amount);


        /// STANDARD TRANSFER  (Wallet-to-Wallet)
        } else {
            _transferStandard(sender, recipient, amount);
        }
    }


    /// @notice struct used for transfer functions
    struct TransferData {
        uint256 tAmountSent;
        uint256 rAmountSent;
        uint256 totalBuyTaxBps;
        uint256 totalSellTaxBps;
        uint256 tBuyFeeTotal;
        uint256 rBuyFeeTotal;
        uint256 tSellFeeTotal;
        uint256 rSellFeeTotal;
        uint256 reflectedAmount;
    }

    event TransferToExcluded(uint256 amountSent, uint256 amountReceived);

    /// @notice allow holder to obtain the max value they can sell in a single transaction
    function getFiftyPercentOfBalance() public view returns(uint256) {
        return (balanceOf(msg.sender) / 2);
    }


    /// @notice RECIPIENT excluded (usually a token sell)
    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        TransferData memory data;

        // require that seller can only ever sell a maximum of 50% of their balance in a single transaction
        require(tAmount <= rBalanceOf(sender) / 2, "Cannot sell more than 50% of balance in single transaction");


        // amount sent from excluded address
        data.tAmountSent = tAmount;
        data.rAmountSent = tAmount * _getRate();

        data.totalSellTaxBps = 0;

        // TOTAL fee as token amount expressed in wei
        data.tSellFeeTotal = (tAmount * data.totalSellTaxBps) / 10000;
        data.rSellFeeTotal = data.tSellFeeTotal * _getRate();

        // fee amount available for reflection, expressed in rSpace
        if (data.rSellFeeTotal > 0 ) {
            data.reflectedAmount = data.rSellFeeTotal;
        }


        // Now distribute fees and amounts //

        /// rOwned values reduced for the SENDER by the FULL amount
        _rOwned[sender] -= data.rAmountSent;

        /// tOwned and rOwned value updated for the recipient (non-excluded address) increased by the amount minus the fee
        _tOwned[recipient] += (data.tAmountSent - data.tSellFeeTotal);
        _rOwned[recipient] += (data.rAmountSent - data.rSellFeeTotal);

        // now reflect the remainder to token holders by subtracting from rTotal
        _rTotal -= data.reflectedAmount;

        // emit Transfer(sender, recipient, tAmountSent);
        emit Transfer(sender, recipient, (data.tAmountSent - data.tSellFeeTotal));

        emit TransferToExcluded(
            data.tAmountSent,
            (data.tAmountSent - data.tSellFeeTotal)
            );
    }

    event TransferFromExcluded(uint256 amountSent, uint256 amountReceived);

    /// @notice SENDER excluded (usually a token buy)
    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        TransferData memory data;

        // amount sent from excluded address
        data.tAmountSent = tAmount;
        data.rAmountSent = tAmount * _getRate();

        // retrieve all values that will be relevant 
        data.totalBuyTaxBps = 0;

        // TOTAL fee as token amount expressed in wei
        data.tBuyFeeTotal = (tAmount * data.totalBuyTaxBps) / 10000;
        data.rBuyFeeTotal = data.tBuyFeeTotal * _getRate();

        // fee amount available for reflection, expressed in rSpace
        if (
            data.rBuyFeeTotal > 0) {
            data.reflectedAmount = data.rBuyFeeTotal;
        }

        // Now distribute fees and amounts //

        /// both tOwned AND rOwned values reduced for the SENDER by the FULL amount
        _tOwned[sender] -= data.tAmountSent;
        _rOwned[sender] -= data.rAmountSent;

        /// rOwned value updated for the recipient (non-excluded address) increased by the amount minus the fee
        _rOwned[recipient] += (data.rAmountSent - data.rBuyFeeTotal);

        // now reflect the remainder to token holders by subtracting from rTotal
        _rTotal -= data.reflectedAmount;

        // emit Transfer(sender, recipient, tAmountSent);
        emit Transfer(sender, recipient, (data.tAmountSent - data.tBuyFeeTotal));
        
        emit TransferFromExcluded(
            data.tAmountSent,
            (data.tAmountSent - data.tBuyFeeTotal)
            );
    }

    event TransferBothExcluded(uint256 amountSent, uint256 amountReceived);



    /// @notice both excluded (token transfer from DEX to DEX) - no fees applied
    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        TransferData memory data;
        // retrieve all values that will be relevant 

        // amount sent from excluded address
        data.tAmountSent = tAmount;
        data.rAmountSent = tAmount * _getRate();

        /// both tOwned AND rOwned values reduced for the SENDER by the FULL amount
        _tOwned[sender] -= data.tAmountSent;
        _rOwned[sender] -= data.rAmountSent;

        /// both tOwned AND rOwned values are updated for recipient
        _tOwned[recipient] += data.tAmountSent;
        _rOwned[recipient] += data.rAmountSent;

        // emit Transfer(sender, recipient, tAmountSent);
        emit Transfer(sender, recipient, data.tAmountSent);

        emit TransferBothExcluded(
            data.tAmountSent,
            data.tAmountSent // same as received amount
            );
    }

    event TransferStandard(uint256 amountSent, uint256 amountReceived);



    /// @notice standard transfer (wallet to wallet)
    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        TransferData memory data;
        // retrieve all values that will be relevant 

        // amount sent from excluded address
        data.tAmountSent = tAmount;
        data.rAmountSent = tAmount * _getRate();      

        // distribution //

        /// rOwned value reduced for the SENDER by the FULL amount
        _rOwned[sender] -= data.rAmountSent;

        // rOwned value increased for the RECEIVER, by rAmount minus the grill fee
        _rOwned[recipient] += data.rAmountSent;

        emit Transfer(sender, recipient, (data.tAmountSent));

        emit TransferStandard(
            data.tAmountSent,
            data.tAmountSent
            );
    }


    /// @notice checks if address is excluded from Max Tx
    function isExcludedFromMaxTx(address account) public view returns (bool) {
        return _isExcludedFromMaxTx[account];
    }

    /// @notice checks if address is excluded from reflection rewards
    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }
    
/////////////////////////////////////////////////////////////////////////////////////////////////////

    // Reflection-related values for potential API

    /// @notice verify account balance in both tSpace and rSpace
    function viewTBalanceRBalance(address _address) public view returns (uint256, uint256) {
        uint256 tBalance = _tOwned[_address];
        uint256 rBalance = _rOwned[_address];
        return(tBalance, rBalance);
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////

}
