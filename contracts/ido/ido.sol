pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract IDO is Ownable, ReentrancyGuard {

    using SafeMath for uint256;


    // Info of each user.
    struct UserInfo {
        uint256 amount;   // 余额
        uint256 total;  //总的数量
    }


    // admin address
    address public adminAddress;
    // The raising token

    // The offering token
    IERC20 public offeringToken;
    // The block number when IFO starts
    uint256 public startBlock;
    // The block number when IFO ends
    uint256 public endTime;
    // total amount of raising tokens need to be raised
    bool public isEnd = false;
    // total amount of raising tokens that have already raised
    uint256 public totalAmount;
    uint256 public exchangeRatio = 500;
    uint256 public metLimit;
    uint256 public weekTime = 28 days;

    uint256 public min = 0.5e18;
    // address => amount
    mapping(address => UserInfo) public userInfo;

    // participators
    address[] public addressList;


    event Deposit(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 offeringAmount);


    constructor(
        IERC20 _offeringToken,
        address _adminAddress
    ) public {
        offeringToken = _offeringToken;
        adminAddress = _adminAddress;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "admin: wut?");
        _;
    }
    function setExRatio(uint256 _rate) public onlyAdmin {
        exchangeRatio = _rate;
    }

    function setWeekTime(uint256 _limit) public onlyAdmin {
        weekTime = _limit;
    }

    function setMetLimit(uint256 _limit) public onlyAdmin {
        metLimit = _limit;
    }
    function setMin(uint256 _limit) public onlyAdmin {
        min = _limit;
    }
    function setEndTime(bool isEnd_) public onlyAdmin {
        isEnd = isEnd_;
        endTime = block.timestamp;
    }


    function deposit() public payable {
        // require(block.number > startBlock && block.number < endBlock, 'not ifo time');
        uint256 _amount = msg.value;
        require(_amount >= min && _amount <= 2e18, 'need _amount > 0');
        require(userInfo[msg.sender].amount.add(_amount) >= 2e18, 'more than limit');
        require(isEnd == false, 'is end');
        require(totalAmount.add(_amount).mul(exchangeRatio) <= metLimit, "met is over");
        if (userInfo[msg.sender].amount == 0) {
            addressList.push(address(msg.sender));
        }
        userInfo[msg.sender].amount = userInfo[msg.sender].amount.add(_amount);
        userInfo[msg.sender].total = userInfo[msg.sender].total.add(_amount);
        totalAmount = totalAmount.add(_amount);
        emit Deposit(msg.sender, _amount);
    }

    function harvest(uint256 amount) public nonReentrant {
        require(isEnd, 'not harvest time');
        require(userInfo[msg.sender].amount > 0, 'have you participated?');
        // require(!userInfo[msg.sender].claimed, 'nothing to harvest');
        if (userInfo[msg.sender].amount == userInfo[msg.sender].total) {
            uint256 offeringTokenAmount = userInfo[msg.sender].amount.mul(exchangeRatio).div(2);
            userInfo[msg.sender].amount = userInfo[msg.sender].amount.div(2);
            // offeringToken.safeTransfer(address(msg.sender), offeringTokenAmount);
            SafeERC20.safeTransfer(
                offeringToken,
                address(msg.sender),
                offeringTokenAmount
            );
            emit Harvest(msg.sender, offeringTokenAmount);
        } else {
            uint256 cur = block.timestamp;
            if (block.timestamp > endTime.add(weekTime)) {
                cur = endTime.add(weekTime);
            }
            uint256 canClaimed = userInfo[msg.sender].total.div(2).mul(cur.sub(endTime)).div(weekTime);
            uint256 remain = userInfo[msg.sender].total.div(2).sub(canClaimed);
            uint256 claim = userInfo[msg.sender].amount.sub(remain);
            userInfo[msg.sender].amount = userInfo[msg.sender].amount.sub(claim);
            if (claim > 0) {
                // offeringToken.safeTransfer(address(msg.sender), claim.mul(exchangeRatio));
                SafeERC20.safeTransfer(
                    offeringToken,
                    address(msg.sender),
                    claim.mul(exchangeRatio)
                );
                emit Harvest(msg.sender, claim.mul(exchangeRatio));
            }

        }


        //userInfo[msg.sender].claimed = true;

    }


    function getPending(address _user) internal view returns (uint256){
        if (userInfo[_user].total == userInfo[_user].amount) {
            return userInfo[_user].total.div(2);
        }
        uint256 cur = block.timestamp;
        if (block.timestamp > endTime.add(weekTime)) {
            cur = endTime.add(weekTime);
        }
        uint256 canClaimed = userInfo[_user].total.div(2).mul(cur.sub(endTime)).div(weekTime);
        uint256 remain = userInfo[_user].total.div(2).sub(canClaimed);
        uint256 claim = userInfo[_user].amount.sub(remain);
        return claim.mul(exchangeRatio);
    }


    function getAddressListLength() external view returns (uint256) {
        return addressList.length;
    }

    function finalWithdraw(uint256 _offerAmount) public onlyAdmin {

        require(_offerAmount <= offeringToken.balanceOf(address(this)), 'not enough token 1');

        if (_offerAmount > 0) {
            // offeringToken.safeTransfer(address(msg.sender), _offerAmount);
            SafeERC20.safeTransfer(
                offeringToken,
                address(msg.sender),
                _offerAmount
            );
        }

    }
}