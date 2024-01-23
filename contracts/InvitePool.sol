// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import "hardhat/console.sol";
//import "./TimeLock.sol";

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be aplied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * > Note: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
//interface IERC20 {
//    function totalSupply() external view returns (uint256);
//
//    function transfer(address to, uint256 value) external returns (bool);
//
//    function approve(address spender, uint256 value) external returns (bool);
//
//    function transferFrom(address from, address to, uint256 value) external returns (bool);
//
//    function balanceOf(address who) external view returns (uint256);
//
//    function allowance(address owner, address spender) external view returns (uint256);
//
//    event Transfer(address indexed from, address indexed to, uint256 value);
//    event Approval(address indexed owner, address indexed spender, uint256 value);
//}

contract InvitePool is Ownable {
    using SafeMath for *;
    //using SafeERC20 for IERC20;
    mapping(address => address[]) public recommend;

    mapping(address => bool) public whiteList;
    mapping(address => address) public upper;

    mapping(address => bool) public drawed;
    mapping(address => bool) public operators;
    address public token;
    uint256 public minHold;
    uint256 public tokenDecimals = 18;
    address public lockAddress;
    //uint256 public airDropValue = 1000000000000000000;
    //TimeLock public lockReward;
    mapping(address => uint256) public airDropValue;
    mapping(address => uint256) public airDropDrawed;
    mapping(address => uint256) public recommendReward;
    modifier onlyOperator() {
        require(operators[msg.sender] == true, "caller is not the operator");
        _;
    }

    constructor() public {

    }


    function setOperator(address[] memory users, bool b) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            operators[users[i]] = b;
        }
    }


    function getOneLevelLists(address addr) public view returns (address[] memory){
        return recommend[addr];
    }


    function getTwoLevelLists(address addr) public view returns (address[] memory){
        address[] memory ones = recommend[addr];
        //twos = new address[](ones.length);
        uint256 k = 0;
        for (uint256 i = 0; i < ones.length; i++) {
            for (uint256 j = 0; j < recommend[ones[i]].length; j++) {
                k++;
            }
        }
        address[]  memory twos = new address[](k);
        for (uint256 i = 0; i < ones.length; i++) {
            for (uint256 j = 0; j < recommend[ones[i]].length; j++) {
                k--;
                twos[k] = recommend[ones[i]][j];

            }
        }
        return twos;
    }

    function getThreeLevelLists(address addr) public view returns (address[] memory){
        address[] memory twos = getTwoLevelLists(addr);
        uint256 k = 0;
        for (uint256 i = 0; i < twos.length; i++) {
            for (uint256 j = 0; j < recommend[twos[i]].length; j++) {
                //threes[k] = recommend[twos[i]][j];
                k++;
            }
        }
        address[] memory threes = new address[](k);
        for (uint256 i = 0; i < twos.length; i++) {
            for (uint256 j = 0; j < recommend[twos[i]].length; j++) {
                k--;
                threes[k] = recommend[twos[i]][j];

            }
        }
        return threes;
    }

    function getFourLevelLists(address addr) public view returns (address[] memory){
        address[] memory threes = getThreeLevelLists(addr);

        uint256 k = 0;
        for (uint256 i = 0; i < threes.length; i++) {
            for (uint256 j = 0; j < recommend[threes[i]].length; j++) {
                //fours[k] = recommend[threes[i]][j];
                k++;
            }
        }
        address[] memory fours = new address[](k);
        for (uint256 i = 0; i < threes.length; i++) {
            for (uint256 j = 0; j < recommend[threes[i]].length; j++) {
                k--;
                fours[k] = recommend[threes[i]][j];
            }
        }
        return fours;
    }


    function getFiveLevelLists(address addr) public view returns (address[] memory){
        address[] memory fours = getFourLevelLists(addr);

        uint256 k = 0;
        for (uint256 i = 0; i < fours.length; i++) {
            for (uint256 j = 0; j < recommend[fours[i]].length; j++) {
                //fours[k] = recommend[threes[i]][j];
                k++;
            }
        }
        address[] memory fives = new address[](k);
        for (uint256 i = 0; i < fours.length; i++) {
            for (uint256 j = 0; j < recommend[fours[i]].length; j++) {
                k--;
                fives[k] = recommend[fours[i]][j];
            }
        }
        return fives;
    }

    function getFiveAllLists(address addr) public view returns (address[] memory){
        address[] memory ones = recommend[addr];

        //twos = new address[](ones.length);
        uint256 k = 0;
        for (uint256 i = 0; i < ones.length; i++) {
            for (uint256 j = 0; j < recommend[ones[i]].length; j++) {
                k++;
            }
        }
        address[]  memory twos = new address[](k);
        for (uint256 i = 0; i < ones.length; i++) {
            for (uint256 j = 0; j < recommend[ones[i]].length; j++) {
                k--;
                twos[k] = recommend[ones[i]][j];

            }
        }

        k = 0;
        for (uint256 i = 0; i < twos.length; i++) {
            for (uint256 j = 0; j < recommend[twos[i]].length; j++) {
                //threes[k] = recommend[twos[i]][j];
                k++;
            }
        }
        address[] memory threes = new address[](k);
        for (uint256 i = 0; i < twos.length; i++) {
            for (uint256 j = 0; j < recommend[twos[i]].length; j++) {
                k--;
                threes[k] = recommend[twos[i]][j];

            }
        }

        k = 0;
        for (uint256 i = 0; i < threes.length; i++) {
            for (uint256 j = 0; j < recommend[threes[i]].length; j++) {
                //fours[k] = recommend[threes[i]][j];
                k++;
            }
        }
        address[] memory fours = new address[](k);
        for (uint256 i = 0; i < threes.length; i++) {
            for (uint256 j = 0; j < recommend[threes[i]].length; j++) {
                k--;
                fours[k] = recommend[threes[i]][j];
            }
        }

        k = 0;
        for (uint256 i = 0; i < fours.length; i++) {
            for (uint256 j = 0; j < recommend[fours[i]].length; j++) {
                //fours[k] = recommend[threes[i]][j];
                k++;
            }
        }
        address[] memory fives = new address[](k);
        for (uint256 i = 0; i < fours.length; i++) {
            for (uint256 j = 0; j < recommend[fours[i]].length; j++) {
                k--;
                fives[k] = recommend[fours[i]][j];
            }
        }
        uint256 total = ones.length + twos.length + threes.length + fours.length + fives.length;
        address[] memory all = new address[](total);
        for (uint256 i = 0; i < ones.length; i++) {
            all[i] = ones[i];
        }
        for (uint256 i = 0; i < twos.length; i++) {
            all[i + ones.length] = twos[i];
        }
        for (uint256 i = 0; i < threes.length; i++) {
            all[i + ones.length + twos.length] = threes[i];
        }
        for (uint256 i = 0; i < fours.length; i++) {
            all[i + ones.length + twos.length + threes.length] = fours[i];
        }
        for (uint256 i = 0; i < fives.length; i++) {
            all[i + ones.length + twos.length + threes.length + fours.length] = fives[i];
        }
        return all;
    }

    // add white list
    function addWhiteList(address _whiteList, address _recommend) internal returns (bool) {
        //console.log("recommend:", _recommend);
        if (whiteList[_whiteList] == false && _recommend != _whiteList) {
            recommend[_recommend].push(_whiteList);
            whiteList[_whiteList] = true;
            upper[_whiteList] = _recommend;
            whiteList[_recommend] = true;
            return true;
        } else {
            return false;
        }


    }
    function addMyRecommend( address _recommend)  external returns (bool) {
        //        if (_self == _recommend || _recommend == address(0)) {
        //          //  _recommend = owner();
        //
        //        }
        return addWhiteList(msg.sender, _recommend);

    }
    function addRecommend(address _self, address _recommend) onlyOperator external returns (bool) {
        //        if (_self == _recommend || _recommend == address(0)) {
        //          //  _recommend = owner();
        //
        //        }
      //  _self = msg.sender;
        return addWhiteList(_self, _recommend);

    }
    //onlyOperator
    function _getUppers(address user) internal view returns (address one, address two, address three, address four){
        one = upper[user];
        if (one != address(0)) {
            two = upper[one];
            if (two != address(0)) {
                three = upper[two];
                if (three != address(0)) {
                    four = upper[three];
                }
            }
        }
    }

    function getOneUpper(address user) public view returns (address one){
        one = upper[user];
    }


    function getUppers(address user) public view returns (address[] memory){
        address one;
        address two;
        address three;
        address four;
        address five;
        address[] memory _upper = new address[](5);
        one = upper[user];
        if (one != address(0)) {
            _upper[0] = one;
            two = upper[one];
            if (two != address(0)) {
                _upper[1] = two;
                three = upper[two];
                if (three != address(0)) {
                    _upper[2] = three;
                    four = upper[three];
                    if (four != address(0)) {
                        _upper[3] = three;
                        five = upper[four];
                        if (five != address(0)) {
                            _upper[4] = five;
                        }
                    }
                }
            }
        }
        return _upper;
    }


    function random()
    internal
    view
    returns (uint256)
    {
        uint256 _seed = uint256(keccak256(abi.encodePacked(
                (block.timestamp).add
                (block.difficulty).add
                ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)).add
                (block.gaslimit).add
                ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)).add
                (block.number)
            )));
        uint256 _rand = _seed % 200;
        if (_rand < 1) _rand = 1;
        return _rand * 10 ** 8;
    }

    //    function withdraw(uint256 amount) external onlyOwner {
    //        IERC20(token).transfer(msg.sender, amount);
    //    }

}