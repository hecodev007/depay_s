// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import "hardhat/console.sol";

import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import './uniswap/UniswapV2Library.sol';
//import "./uniswap/IUniswapV2Factory.sol";
//import "./uniswap/IUniswapV2Router02.sol";
//import "./uniswap/IUniswapV2Callee.sol";
//import "./uniswap/IUniswapV2Pair.sol";
import "./uniswap/IWETH.sol";

contract Pay is Ownable {
    using SafeMath for uint256;

    // bytes32 public root;

    IERC20  public tokenERC20;


    mapping(address => bool) public baseTokenList;//稳定币
    address[] baseTokens;
    address  public adminer;
    address public FACTORY;
    address public ROUTER;
    ISwapRouter public immutable swapRouter;
    address public WETH;
    address private feeWallet;
    IERC20 public usdtToken;
    uint24 public constant poolFee = 3000;
    //user=>merchant=>product=>period
    mapping(address => mapping(address => mapping(uint256 => uint256))) public subScribe;

    struct Merchant {
        uint256 merchantId;
        uint256 feePoint;
        uint256 feeDenominator;
        uint256 balance;
    }

    //    struct Scribe {
    //        address merchant;
    //        uint256 merchantId;
    //        uint256 lastTime;
    //    }

    //merchant=>token=>info
    mapping(address => mapping(address => Merchant)) public merchantInfo;
    /*
    payToken 用什么token支付的
    tokenAmount token 的数量
    payAmount   以u计算的应该支付的数量
    swapAmount  token swap后得到u的数量
    fee 手续费
    */
    event PayOrderEvent(uint256 orderId, address user, address merchant, address payToken, uint256 tokenAmount, uint256 payAmount, uint256 swapAmount, uint256 fee, address recToken);
    event MerchantWithdrawEvent(address user, address _usdt, uint256 amount);
    event SubScribe(address user, address merchant, uint256 product, uint256 _period);
    event CancelSubScribe(address user, address merchant, uint256 product);
    event SubScribePay(address user, address merchant, address _token, uint256 amount, uint256 fee);
    // uint24 public constant poolFee = 3000;
    receive() external payable {
        revert("R");
    }

    constructor(address[] memory tokens, address _usdt, address _weth, address _feeWallet, address _router) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            baseTokenList[tokens[i]] = true;
            baseTokens.push(tokens[i]);

        }
        usdtToken = IERC20(_usdt);
        //   FACTORY = _factory;
        WETH = _weth;
        ROUTER = _router;
        swapRouter = ISwapRouter(_router);

        feeWallet = _feeWallet;

    }


    function setToken(address _tokenERC20, bool power) public onlyOwner {
        if (!baseTokenList[_tokenERC20]) {
            baseTokens.push(_tokenERC20);
        }
        baseTokenList[_tokenERC20] = power;

    }

    function setAdmin(address _admin) public onlyOwner {
        adminer = _admin;
    }

    //支持新增一个base token
    function addMerchantBase(address _merchant, uint256 _id, address _token, uint256 _point, uint256 _denominator) public onlyOwner {
        require(baseTokenList[_token], "error base token");
        if (merchantInfo[_merchant][_token].merchantId == 0) {
            merchantInfo[_merchant][_token] = Merchant(
            {
            merchantId : _id,
            feePoint : _point,
            feeDenominator : _denominator,
            balance : 0
            }
            );
        }

    }
    //添加商户
    function addMerchant(address _merchant, uint256 _id, uint256 _point, uint256 _denominator) public onlyOwner {
        for (uint256 i = 0; i < baseTokens.length; i++) {
            if (merchantInfo[_merchant][baseTokens[i]].merchantId == 0) {
                merchantInfo[_merchant][baseTokens[i]] = Merchant(
                {
                merchantId : _id,
                feePoint : _point,
                feeDenominator : _denominator,
                balance : 0
                }
                );
            }
        }
    }

    //修改商户信息
    function setMerchant(address _merchant, uint256 _point, uint256 _denominator) public onlyOwner {
        require(_denominator == 10 || _denominator == 100 || _denominator == 1000 || _denominator == 10000, "invalid denom");
        for (uint256 i = 0; i < baseTokens.length; i++) {
            Merchant storage merchant = merchantInfo[_merchant][baseTokens[i]];
            if (merchant.merchantId != 0) {
                merchant.feeDenominator = _denominator;
                merchant.feePoint = _point;
            }

        }

    }
    //修改商户信息
    function setMerchantId(address _merchant, uint256 _id) public onlyOwner {
        //   require(_denominator == 10 || _denominator == 100 || _denominator == 1000 || _denominator == 10000, "invalid denom");
        for (uint256 i = 0; i < baseTokens.length; i++) {
            Merchant storage merchant = merchantInfo[_merchant][baseTokens[i]];
            if (merchant.merchantId != 0) {
                merchant.merchantId = _id;
            }

        }

    }

    function getMerchantInfo(address _merchant, address token) public view returns (uint256, uint256, uint256){
        return (merchantInfo[_merchant][token].merchantId, merchantInfo[_merchant][token].feePoint, merchantInfo[_merchant][token].feeDenominator);
    }

    function getMerchantBalance(address _merchant, address token) public view returns (uint256){
        return merchantInfo[_merchant][token].balance;
    }

    //    function merchantWithdraw(address token) external {
    //        require(baseTokenList[token], "not allowed token");
    //        Merchant storage merchant = merchantInfo[msg.sender][token];
    //        require(merchant.balance > 0, "no balance");
    //        uint256 bal = IERC20(token).balanceOf(address(this));
    //        // console.log(bal/1e18);
    //        if (bal >= merchant.balance) {
    //            SafeERC20.safeTransfer(
    //                IERC20(token),
    //                address(msg.sender),
    //                merchant.balance
    //            );
    //            merchant.balance = 0;
    //            emit MerchantWithdrawEvent(msg.sender, token, merchant.balance);
    //        } else if (bal > 0) {
    //            SafeERC20.safeTransfer(
    //                IERC20(token),
    //                address(msg.sender),
    //                bal
    //            );
    //            merchant.balance = merchant.balance.sub(bal);
    //            emit MerchantWithdrawEvent(msg.sender, token, bal);
    //        }
    //    }





    function swapExactOutputMultihop(uint256 amountOut, uint256 amountInMaximum, address _sender, address _token, address to, bytes calldata path) internal returns (uint256 amountIn) {
        // Transfer the specified `amountInMaximum` to this contract.
        //        if (_sender != address(this))
        //        {
        //            TransferHelper.safeTransferFrom(_token, _sender, address(this), amountInMaximum);
        //        }

        // Approve the router to spend  `amountInMaximum`.
        TransferHelper.safeApprove(_token, ROUTER, amountInMaximum);

        // The parameter path is encoded as (tokenOut, fee, tokenIn/tokenOut, fee, tokenIn)
        // The tokenIn/tokenOut field is the shared token between the two pools used in the multiple pool swap. In this case USDC is the "shared" token.
        // For an exactOutput swap, the first swap that occurs is the swap which returns the eventual desired token.
        // In this case, our desired output token is WETH9 so that swap happpens first, and is encoded in the path accordingly.
        ISwapRouter.ExactOutputParams memory params =
        ISwapRouter.ExactOutputParams({
        path : path,
        recipient : address(this),
        deadline : block.timestamp + 1 minutes,
        amountOut : amountOut,
        amountInMaximum : amountInMaximum
        });

        console.log(1);
        // Executes the swap, returning the amountIn actually spent.
        amountIn = swapRouter.exactOutput(params);
        console.log(2);
        // If the swap did not require the full amountInMaximum to achieve the exact amountOut then we refund msg.sender and approve the router to spend 0.
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(_token, address(swapRouter), 0);
            TransferHelper.safeTransferFrom(_token, address(this), _sender, amountInMaximum - amountIn);
        }
    }

    function convertEthToWETH(uint256 amount) internal {
        IWETH(WETH).deposit{value : amount}();
    }

    function changeMerchantBalance(address _merchant, address token, uint256 usdtAmount) internal returns (uint256) {
        if (merchantInfo[_merchant][token].feePoint != 0) {
            uint256 fee = usdtAmount.mul(merchantInfo[_merchant][token].feePoint).div(merchantInfo[_merchant][token].feeDenominator);
            //            merchantInfo[owner()][token].balance = merchantInfo[owner()][token].balance.add(fee);
            //            merchantInfo[_merchant][token].balance = merchantInfo[_merchant][token].balance.add(usdtAmount.sub(fee));
            if (token != address(0)) {
                SafeERC20.safeTransfer(IERC20(token), _merchant, usdtAmount.sub(fee));
                SafeERC20.safeTransfer(IERC20(token), feeWallet, fee);
            } else {
                address payable merchant_ = address(uint160(_merchant));
                merchant_.transfer(usdtAmount.sub(fee));
                address payable feeWallet_ = address(uint160(feeWallet));
                feeWallet_.transfer(usdtAmount.sub(fee));
            }

            return fee;
        } else {
            //merchantInfo[_merchant][token].balance = merchantInfo[_merchant][token].balance.add(usdtAmount);
            if (token != address(0)) {
                SafeERC20.safeTransfer(IERC20(token), _merchant, usdtAmount);
            } else {
                address payable merchant_ = address(uint160(_merchant));
                merchant_.transfer(usdtAmount);
            }
        }
        return 0;
    }

    function subScribes(
        address _merchant, uint256 _product, uint256 _period
    ) public {
        require(merchantInfo[_merchant][address(usdtToken)].merchantId != 0, "wrong param");
        uint256 _dec = ERC20(address(usdtToken)).decimals();
        require(ERC20(address(usdtToken)).allowance(msg.sender, address(this)) >= 100000 * (10 ** _dec), "low allownce");
        subScribe[msg.sender][_merchant][_product] = _period;
        emit SubScribe(msg.sender, _merchant, _product, _period);
    }

    function cancelSubScribe(
        address _merchant, uint256 _product
    ) public {
        require(merchantInfo[_merchant][address(usdtToken)].merchantId != 0, "wrong param");
        subScribe[msg.sender][_merchant][_product] = 0;
        emit CancelSubScribe(msg.sender, _merchant, _product);
    }

    function subScribePay(address _merchant, address _user, address _token, uint256 usdtAmount, uint256 _product) public onlyOwner {
        require(baseTokenList[_token], "not base token");
        require(subScribe[_user][_merchant][_product] != 0, "not sub");
        SafeERC20.safeTransferFrom(IERC20(_token), _user, address(this), usdtAmount);
        uint256 fee = changeMerchantBalance(_merchant, _token, usdtAmount);
        emit SubScribePay(_user, _merchant, _token, usdtAmount, fee);
    }

    function payOrder(
        uint256 usdtAmount,
        uint256 tokenAmount,
        uint256 _orderid,
        address _token,
        address _merchant,
        uint256 _merchantId,
        bytes calldata path) external payable {
        if (baseTokenList[_token]) {
            require(merchantInfo[_merchant][_token].merchantId != 0 && merchantInfo[_merchant][_token].merchantId == _merchantId, "bad merchant id");
        } else {
            require(merchantInfo[_merchant][address(usdtToken)].merchantId != 0 && merchantInfo[_merchant][address(usdtToken)].merchantId == _merchantId, "bad merchant");
        }

        if (msg.value > 0) {//主币
            _token = address(0);
            if (baseTokenList[_token]) {
                require(msg.value == usdtAmount, "error msg.value");
                uint256 fee = changeMerchantBalance(_merchant, address(0), msg.value);
                emit PayOrderEvent(_orderid, msg.sender, _merchant, _token, tokenAmount, usdtAmount, 0, fee, address(0));
                return;
            }
            convertEthToWETH(msg.value);
            console.log("WETH balance:");
            console.log(IWETH(WETH).balanceOf(address(this)));
            swapExactOutputMultihop(usdtAmount, msg.value, msg.sender, WETH, address(this), path);
            uint256 _swapUsdtAmount = usdtAmount;
            uint256 fee = changeMerchantBalance(_merchant, address(usdtToken), usdtAmount);
            emit PayOrderEvent(_orderid, msg.sender, _merchant, _token, tokenAmount, usdtAmount, _swapUsdtAmount, fee, address(usdtToken));
        } else {
            //require(tokenList[_token] == true, "not allowed token");
            tokenERC20 = IERC20(_token);

            require(tokenERC20.balanceOf(address(msg.sender)) >= tokenAmount, "token balance is not enough");
            require(tokenERC20.allowance(msg.sender, address(this)) >= tokenAmount, "token allowance is not enough");
            if (!baseTokenList[_token]) {//非稳定币支付
                //                uint256 _swapUsdtAmount = sellTokenToToken(tokenAmount, msg.sender, _token, address(this), path);
                //                require(usdtAmount <= _swapUsdtAmount, "bad tokenAmount");
                //                if (_swapUsdtAmount > usdtAmount) {
                //                    usdtToken.transfer(msg.sender, _swapUsdtAmount.sub(usdtAmount));
                //                }
                TransferHelper.safeTransferFrom(_token, msg.sender, address(this), tokenAmount);
                swapExactOutputMultihop(usdtAmount, tokenAmount, msg.sender, _token, address(this), path);
                uint256 _swapUsdtAmount = usdtAmount;
                uint256 fee = changeMerchantBalance(_merchant, address(usdtToken), usdtAmount);
                emit PayOrderEvent(_orderid, msg.sender, _merchant, _token, tokenAmount, usdtAmount, _swapUsdtAmount, fee, address(usdtToken));
            } else {//稳定币支付
                SafeERC20.safeTransferFrom(IERC20(_token), msg.sender, address(this), usdtAmount);
                uint256 fee = changeMerchantBalance(_merchant, _token, usdtAmount);
                emit PayOrderEvent(_orderid, msg.sender, _merchant, _token, tokenAmount, usdtAmount, 0, fee, _token);
            }

        }


    }
}
