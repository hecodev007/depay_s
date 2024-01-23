// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/InitializableOwner.sol";
//import "../interfaces/IDsgNft.sol";
//import "../libraries/LibPart.sol";
//import "../libraries/Random.sol";


library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value : value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

contract GeneralNft is ERC721, InitializableOwner, ReentrancyGuard, Pausable
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _minters;
    using Strings for uint256;
    //mapping(address => uint256) UserChance;

    event CrystalNftMinted(
        uint256 indexed id,
        address to
    );

    //  event Upgraded(uint256 indexed id0, uint256 indexed id1, uint256 new_id, address user);

    /*
     *     bytes4(keccak256('getRoyalties(uint256)')) == 0xbb3bafd6
     *     bytes4(keccak256('sumRoyalties(uint256)')) == 0x09b94e2a
     *
     *     => 0xbb3bafd6 ^ 0x09b94e2a == 0xb282e1fc
     */
    bytes4 private constant _INTERFACE_ID_GET_ROYALTIES = 0xbb3bafd6;
    bytes4 private constant _INTERFACE_ID_ROYALTIES = 0xb282e1fc;

    uint256 private _tokenId;
    string private _baseURIVar;


    string private _name;
    string private _symbol;

    mapping(address => bool) private operators;
    modifier onlyOperator() {
        require(operators[msg.sender] == true, "caller is not the operator");
        _;
    }

    constructor() public ERC721("", "")
    {
        super._initialize();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) public onlyOwner {
        _tokenId = 1000;

        _registerInterface(_INTERFACE_ID_GET_ROYALTIES);
        _registerInterface(_INTERFACE_ID_ROYALTIES);
        _name = name_;
        _symbol = symbol_;
        _baseURIVar = baseURI_;

    }


    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function setBaseURI(string memory uri) public onlyOwner {
        _baseURIVar = uri;
    }

    function setOperator(address _operator) public onlyOwner {
        operators[_operator] = true;
    }

    function baseURI() public view override returns (string memory) {
        return _baseURIVar;
    }


    function _doMint(
        address to
    ) internal returns (uint256) {
        _tokenId++;


        _mint(to, _tokenId);

        emit CrystalNftMinted(_tokenId, to);
        return _tokenId;
    }

    function mint(
        address to
    ) public nonReentrant onlyOperator returns (uint256 tokenId){
        //  require(msg.value >= price, "low price");

        //TransferHelper.safeTransferETH(_teamWallet, msg.value);
        //        if (address(_token) != address(0)) {
        //            TransferHelper.safeTransferFrom(address(_token), msg.sender, _teamWallet, price);
        //        }
        //
        //        if (address(_tokenOther) != address(0)) {
        //            TransferHelper.safeTransferFrom(address(_tokenOther), msg.sender, _teamWallet, price_other);
        //        }
        tokenId = _doMint(to);
    }

    function getCurId() public view returns (uint256){
        return _tokenId;
    }

    function burn(uint256 tokenId) public {
        address owner = ERC721.ownerOf(tokenId);
        require(_msgSender() == owner, "caller is not the token owner");

        _burn(tokenId);
    }

}
