// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/InitializableOwner.sol";
//import "../interfaces/IDsgNft.sol";
import "../libraries/LibPart.sol";
import "../libraries/Random.sol";
import "./CrystalNft.sol";
import "hardhat/console.sol";
import "../interfaces/IInvitePool.sol";

contract DsgNft is ERC721, InitializableOwner, IERC721Receiver, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _minters;
    IInvitePool public inviteLayer;
    using Strings for uint256;
    mapping(address => uint256) public UserChance;

    event Minted(uint256 indexed id, address to);
    event BatchMinted(uint256[] id, address to);
    event Upgraded(uint256 id0, uint256 id1, uint256 new_id, address user);
    event ComposeNft(
        uint256 id0,
        uint256 id1,
        uint256 new_id,
        address user,
        uint256 compose_id
    );
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

    IERC20 public _token; //egc
    IERC20 public _busd;
    address   public lockNft;
    CrystalNft private _crystalNft;
    //address public _feeWallet;

    string private _name;
    string private _symbol;
    mapping(address => uint256) public invite_reward;

    struct cost {
        uint256 cost;
        uint256 inviteReward;
    }

    struct costList {
        address user;
        uint256 cost;
        uint256 inviteReward;
    }

    mapping(address => uint256) public whiteList;
    bool public whiteEnable = true;
    IERC721 public whiteNft;
    mapping(address => cost) public user_cost;
    uint256 public price;
    uint256 public price_busd;
    // mapping(uint256 => LibPart.NftInfo) private _nfts;
    address public _teamWallet;
    address public _rewardWallet;
    address public _PveWallet;
    uint256 public PVEBUSD;

    constructor() public ERC721("", "") {
        super._initialize();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address teamAddress_,
    // address pveAddress_,
        string memory baseURI_
    ) public onlyOwner {
        _tokenId = 1000;

        _registerInterface(_INTERFACE_ID_GET_ROYALTIES);
        _registerInterface(_INTERFACE_ID_ROYALTIES);
        _name = name_;
        _symbol = symbol_;
        _baseURIVar = baseURI_;
        _teamWallet = teamAddress_;
        // _PveWallet = pveAddress_;
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

    function baseURI() public view override returns (string memory) {
        return _baseURIVar;
    }

    //设置pve钱包
    function setPveWallet(address pveWallet_) public onlyOwner {
        _PveWallet = pveWallet_;
    }

    //设置兑换白名单 nft地址
    function setWhiteNft(address _nft) public onlyOwner {
        whiteNft = IERC721(_nft);
    }

    function setWhiteEnable(bool en) public onlyOwner {
        whiteEnable = en;
    }

    function addWhiteList(address[] memory _user, uint256[] memory set_) public onlyOwner {
        for (uint256 i = 0; i < _user.length; i++) {
            whiteList[_user[i]] = set_[i];
        }

    }

    //设置邀请合约
    function setInvitePool(address inviteLayer_) public onlyOwner {
        inviteLayer = IInvitePool(inviteLayer_);
    }
    //设置水晶资源质押的合约
    function setRewardWallet(address rewardWallet) public onlyOwner {
        _rewardWallet = rewardWallet;
    }
    //设置水晶资源合约
    function setCrystalNft(address crystalNft_) public onlyOwner {
        _crystalNft = CrystalNft(crystalNft_);
    }

    function setTeamAddress(address teamAddr_) public onlyOwner {
        _teamWallet = teamAddr_;
    }
    //设置卖价
    function setPrice(uint256 price_, uint256 price_busd_) public onlyOwner {
        price = price_;
        price_busd = price_busd_;
    }

    function setFeeToken(address token, address token_busd) public onlyOwner {
        _token = IERC20(token);
        _busd = IERC20(token_busd);
    }

    //兑换将nft锁起来
    function setLockNft(address _lockNft) public onlyOwner {
        lockNft = _lockNft;
    }

    function _doMint(address to) internal returns (uint256) {
        _tokenId++;

        _mint(to, _tokenId);

        emit Minted(_tokenId, to);
        return _tokenId;
    }

    function getInvitorCost(address _user)
    public
    view
    returns (costList[] memory)
    {
        address[] memory users = inviteLayer.getOneLevelLists(_user);
        costList[] memory lists = new costList[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            costList memory cost = costList({
            user : users[i],
            cost : user_cost[users[i]].cost,
            inviteReward : user_cost[users[i]].inviteReward
            });
            lists[i] = cost;
        }
        return lists;
    }

    //用其它nft来兑换nft
    function freeMint(address to, uint256[] memory tokenIds) public nonReentrant {
        require(tokenIds.length > 0, "low amount");
        require(address(whiteNft) != address(0), "no whiteNft");

        //  whiteList[msg.sender] = whiteList[msg.sender].sub(amount.div(5));
        for (uint i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            whiteNft.safeTransferFrom(
                address(msg.sender),
                lockNft,
                tokenId
            );
        }

        uint256 amount = tokenIds.length.mul(5);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (getReward(msg.sender) == true) {
                _crystalNft.mint(msg.sender);
            }
        }

        uint256[] memory nftIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            nftIds[i] = _doMint(to);
        }
        emit BatchMinted(nftIds, to);
    }
    //    function freeMint(address to, uint256 amount) public nonReentrant {
    //        require(amount >= 5, "low amount");
    //        require(whiteList[msg.sender] < amount.div(5), "not white list");
    //
    //        whiteList[msg.sender] = whiteList[msg.sender].sub(amount.div(5));
    //
    //        for (uint256 i = 0; i < amount / 5; i++) {
    //            if (getReward(msg.sender) == true) {
    //                _crystalNft.mint(msg.sender);
    //            }
    //        }
    //
    //        uint256[] memory nftIds = new uint256[](amount);
    //        for (uint256 i = 0; i < amount; i++) {
    //            nftIds[i] = _doMint(to);
    //        }
    //        emit BatchMinted(nftIds, to);
    //    }

    function freeMintInternal(address to, uint256 amount) internal returns (bool) {
        if (whiteList[msg.sender] < amount.div(5)) {
            return false;
        }
        whiteList[msg.sender] = whiteList[msg.sender].sub(amount.div(5));

        for (uint256 i = 0; i < amount / 5; i++) {
            if (getReward(msg.sender) == true) {
                _crystalNft.mint(msg.sender);
            }
        }

        uint256[] memory nftIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            nftIds[i] = _doMint(to);
        }
        emit BatchMinted(nftIds, to);
        return true;
    }

    //批量铸造nft
    function batchMint(address to, uint256 amount) public payable nonReentrant {
        require(amount >= 5, "low amount");
        require(_teamWallet != address(0), "_teamWallet");
        //        if (freeMintInternal(to, amount) == true) {
        //           return;
        //        }else{
        //            if (whiteEnable) {
        //                return;
        //            }
        //        }

        if (address(_token) != address(0)) {
            _token.safeTransferFrom(
                address(msg.sender),
                _teamWallet,
                price.mul(amount)
            );
        }
        cost storage userCost = user_cost[msg.sender];
        if (address(_busd) != address(0)) {
            address upper = inviteLayer.getOneUpper(msg.sender);
            uint256 money = price_busd.mul(amount);

            uint256 percent = 0;
            if (upper != address(0)) {
                uint256 reward = money.mul(5).div(100);
                _busd.safeTransferFrom(address(msg.sender), upper, reward);
                percent = percent.add(5);
                invite_reward[upper] = invite_reward[upper].add(reward);
                userCost.inviteReward = userCost.inviteReward.add(reward);
                userCost.cost = userCost.cost.add(money);
            }
            if (_rewardWallet != address(0)) {
                _busd.safeTransferFrom(
                    address(msg.sender),
                    _rewardWallet,
                    money.mul(15).div(100)
                );
                percent = percent.add(15);
            }
            if (_PveWallet != address(0)) {
                _busd.safeTransferFrom(
                    address(msg.sender),
                    _PveWallet,
                    money.mul(40).div(100)
                );
                percent = percent.add(40);
                PVEBUSD = PVEBUSD.add(money.mul(40).div(100));
            }

            _busd.safeTransferFrom(
                address(msg.sender),
                _teamWallet,
                money.mul(100 - percent).div(100)
            );

        }
        for (uint256 i = 0; i < amount / 5; i++) {
            if (getReward(msg.sender) == true) {
                _crystalNft.mint(msg.sender);
            }
        }

        uint256[] memory nftIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            nftIds[i] = _doMint(to);
        }
        emit BatchMinted(nftIds, to);
    }

    //是否能获取资源水晶
    function getReward(address user) internal returns (bool) {
        uint256 seed = (Random.computerSeed() / 23) % 100;
        uint256 chance = UserChance[user];
        if (chance > 0) {
            UserChance[user] = chance + 5;
            if (seed <= chance + 5) {
                UserChance[user] = 0;
                return true;
            } else {
                return false;
            }
        } else {
            UserChance[user] = 5;
            if (seed <= 1) {
                UserChance[user] = 0;
                return true;
            } else {
                return false;
            }
        }
    }

    function mint(address to)
    public
    payable
    nonReentrant
    returns (uint256 tokenId)
    {
        //  require(msg.value >= price, "low price");
        //SafeERC20.safeTransferETH(_teamWallet, msg.value);
        if (address(_token) != address(0)) {
            _token.safeTransferFrom(address(msg.sender), _teamWallet, price);
        }

        if (address(_busd) != address(0)) {
            _busd.safeTransferFrom(
                address(msg.sender),
                _teamWallet,
                price_busd
            );
        }
        tokenId = _doMint(to);
    }

    function upgradeNft(uint256 nftId1, uint256 nftId2)
    public
    nonReentrant
    whenNotPaused
    {
        burn_inter(nftId1);
        burn_inter(nftId2);
        uint256 tokenId = _doMint(msg.sender);
        emit Upgraded(nftId1, nftId2, tokenId, msg.sender);
    }
//合成nft
    function composeNft(
        uint256 nftId1,
        uint256 nftId2,
        uint256 composeId
    ) public nonReentrant whenNotPaused {
        burn_inter(nftId1);
        burn_inter(nftId2);
        uint256 tokenId = _doMint(msg.sender);
        //ComposeNft
        emit ComposeNft(nftId1, nftId2, tokenId, msg.sender, composeId);
    }

    function getCurId() public view returns (uint256) {
        return _tokenId;
    }
//销毁nft
    function burn(uint256 tokenId) public {
        address owner = ERC721.ownerOf(tokenId);
        require(_msgSender() == owner, "caller is not the token owner");

        _burn(tokenId);
    }

    function burn_inter(uint256 tokenId) internal {
        address owner = ERC721.ownerOf(tokenId);
        require(_msgSender() == owner, "caller is not the token owner");

        _burn(tokenId);
    }

    function onERC721Received(
        address operator,
        address, //from
        uint256, //tokenId
        bytes calldata //data
    ) public override nonReentrant returns (bytes4) {
        require(
            operator == address(this),
            "received Nft from unauthenticated contract"
        );

        return
        bytes4(
            keccak256("onERC721Received(address,address,uint256,bytes)")
        );
    }
}
