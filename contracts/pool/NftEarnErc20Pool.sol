// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "../interfaces/IDsgNft.sol";
import "hardhat/console.sol";

contract NftEarnErc20Pool is Ownable, IERC721Receiver, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct UserInfo {
        EnumerableSet.UintSet nfts;
        uint slots; //Number of enabled card slots
        mapping(uint => uint256[]) slotNfts; //slotIndex:tokenIds
        mapping(uint => SlotInfo) slotInfo;
    }

    struct SlotInfo {
        uint256 share; // How many powers the user has provided.
        uint256 rewardDebt; // Reward debt.
        uint256 accRewardAmount;
        uint256 harvestTime;
        uint256 startBlock;
        uint256 originStartTime;
        uint256 mineId;
        uint256 energy;
    }

    struct PoolView {
        address rewardToken;
        // uint8 rewardDecimals;
        uint256 lastRewardBlock;
        uint256 rewardsPerBlock;
        uint256 accRewardPerShare;
        uint256 allocRewardAmount;
        uint256 accRewardAmount;
        uint256 totalAmount;
        address nft;
        string nftSymbol;
    }

    uint constant MAX_LEVEL = 6;


    IERC20 public rewardToken;

    uint256 public rewardTokenPerBlock;

    IDsgNft public dsgNft; // Address of NFT token contract.

    uint256 public constant BONUS_MULTIPLIER = 1;

    mapping(address => UserInfo) private userInfo;
    EnumerableSet.AddressSet private _callers;
    mapping(uint256 => uint256) private nftPower;
    //uint[5][5] grade =[[600,650,700,750,800],[900,950,1000,1050,1100],[1200,1250,1300,1350,1400],[1500,1550,1600,1650,1700],[1800,1850,1900,1950,2000]];
    uint256 public startBlock;
    uint256 public endBlock;

    address  public activityPool;
    address  public stealPool;
    uint256 public activityAmount;
    uint256 public stealAmount;

    uint256 lastRewardBlock; //Last block number that TOKENs distribution occurs.
    uint256 accRewardTokenPerShare; // Accumulated TOKENs per share, times 1e12. See below.
    uint256 accShare;
    uint256 public allocRewardAmount; //Total number of rewards to be claimed
    uint256 public accRewardAmount; //Total number of rewards

    uint256 public limitTime = 12 hours;
    uint256 public harvestLimitTime = 1 hours;

    event Stake(address indexed user, uint256 tokenId);
    event StakeWithSlot(address user, uint256 slot, uint256[] tokenIds, uint256 power, uint256 energy);
    event WithdrawSlot(address user, uint256 slot);
    event Withdraw(address indexed user, uint256 tokenId);
    event EmergencyWithdraw(address indexed user, uint256 tokenId);
    //    event WithdrawSlot(address indexed user, uint slot);
    //    event EmergencyWithdrawSlot(address indexed user, uint slot);

    constructor(
        address _rewardToken,
        address _nftAddress,
        uint256 _startBlock
    ) public {
        dsgNft = IDsgNft(_nftAddress);
        rewardToken = IERC20(_rewardToken);
        if (_startBlock == 0) {
            _startBlock = block.number;
        }
        startBlock = _startBlock;
        lastRewardBlock = _startBlock;
        endBlock = _startBlock.add(10000000);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
    public
    pure
    returns (uint256)
    {
        return _to.sub(_from);
    }


    //获取矿池id
    function getMineId(address _user, uint256 slot) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        return user.slotInfo[slot].mineId;
    }
    //挖矿奖励计算
    function calReward(address _user, uint256 slot, uint256 mulper, uint256 util24) internal view returns (uint256){
        UserInfo storage user = userInfo[_user];
        uint256 tmp = 0;
        uint256 share = user.slotInfo[slot].share;
        if (user.slotInfo[slot].mineId == 1) {//低级

            if (share >= 5000) {
                tmp = util24.sub(user.slotInfo[slot].harvestTime).mul(share.sub(5000).mul(0.00002e18).add(0.0045e18)).mul(mulper).div(10);
                return block.timestamp.sub(util24).mul(share.sub(5000).mul(0.00002e18).add(0.0045e18)).add(tmp).div(3);
            } else {
                tmp = util24.sub(user.slotInfo[slot].harvestTime).mul(0.0045e18).mul(mulper).div(10);
                return block.timestamp.sub(util24).mul(0.0045e18).add(tmp).div(3);
            }
        }
        if (user.slotInfo[slot].mineId == 2) {//中级

            tmp = util24.sub(user.slotInfo[slot].harvestTime).mul(share.sub(7000).mul(0.000125e18).add(0.03375e18)).mul(mulper).div(10);
            return block.timestamp.sub(util24).mul(share.sub(7000).mul(0.000125e18).add(0.03375e18)).add(tmp).div(3);
        }
        if (user.slotInfo[slot].mineId == 3) {//高级
            tmp = util24.sub(user.slotInfo[slot].harvestTime).mul(share.sub(9000).mul(0.00375e18).add(0.3125e18)).mul(mulper).div(10);
            return block.timestamp.sub(util24).mul(share.sub(9000).mul(0.00375e18).add(0.3125e18)).add(tmp).div(3);
        }
        return 0;
    }
    // 用户奖励
    function pendingToken(address _user, uint256 slot) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 share = user.slotInfo[slot].share;
        uint256 cur = block.number;
        // console.log("blocks:", cur);
        if (share == 0 || user.slotInfo[slot].startBlock == 0 || user.slotInfo[slot].harvestTime == 0) {
            return 0;
        }
        uint256 mulper = 10;
        if (user.slotInfo[slot].energy == 7200) {
            mulper = 15;
        } else if (user.slotInfo[slot].energy == 14400) {
            mulper = 20;
        }
        uint256 util24 = user.slotInfo[slot].originStartTime.add(24 hours);
        if (block.timestamp.sub(user.slotInfo[slot].originStartTime) <= 24 hours || user.slotInfo[slot].harvestTime >= util24) {
            if (user.slotInfo[slot].harvestTime >= util24) {
                mulper = 10;
            }
            //console.log(1);
            if (user.slotInfo[slot].mineId == 1) {//低级
                if (share >= 5000) {
                    return cur.sub(user.slotInfo[slot].startBlock).mul(share.sub(5000).mul(0.00002e18).add(0.0045e18)).mul(mulper).div(10);
                } else {
                    return cur.sub(user.slotInfo[slot].startBlock).mul(0.0045e18).mul(mulper).div(10);
                }
            }
            if (user.slotInfo[slot].mineId == 2) {//中级
                return cur.sub(user.slotInfo[slot].startBlock).mul(share.sub(7000).mul(0.000125e18).add(0.03375e18)).mul(mulper).div(10);
            }
            if (user.slotInfo[slot].mineId == 3) {//高级
                return cur.sub(user.slotInfo[slot].startBlock).mul(share.sub(9000).mul(0.00375e18).add(0.3125e18)).mul(mulper).div(10);
            }
        } else {
            //address _user, uint256 slot, uint256 mulper,uint256 util24
            // console.log(2, block.timestamp.sub(user.slotInfo[slot].originStartTime).div(1 hours));
            return calReward(_user, slot, mulper, util24);
        }

        return 0;
    }


    function getPoolInfo() public view
    returns (
        uint256 accShare_,
        uint256 accRewardTokenPerShare_,
        uint256 rewardTokenPerBlock_
    )
    {
        accShare_ = accShare;
        accRewardTokenPerShare_ = accRewardTokenPerShare;
        rewardTokenPerBlock_ = rewardTokenPerBlock;
    }

    function setRewardTokenPerBlock(uint256 _rewardTokenPerBlock) public onlyOwner {
        rewardTokenPerBlock = _rewardTokenPerBlock;
    }

    function setEndBlock(uint256 _endblock) public onlyOwner {
        endBlock = _endblock;
    }

    function setNft(uint256 _nft) public onlyOwner {
        dsgNft = IDsgNft(_nft);
    }

    function setStealPool(address _steal) public onlyOwner {
        stealPool = _steal;
    }

    function setActivityPool(address _activity) public onlyOwner {
        activityPool = _activity;
    }
    //惩罚作弊的
    function punishCheat(address _user, uint256 pkId) public onlyOwner {
        UserInfo storage user = userInfo[_user];
        user.slots = user.slots.sub(1);
        user.slotInfo[pkId].share = 0;
        uint256[] memory tokenIds = user.slotNfts[pkId];
        for (uint i = 0; i < tokenIds.length; i++) {
            user.nfts.remove(tokenIds[i]);
        }
        delete user.slotNfts[pkId];
    }

    function getPoolView() public view returns (PoolView memory) {
        return PoolView({
        rewardToken : address(rewardToken),
        //  rewardDecimals : IERC20Metadata(address(rewardToken)).decimals(),
        lastRewardBlock : lastRewardBlock,
        rewardsPerBlock : rewardTokenPerBlock,
        accRewardPerShare : accRewardTokenPerShare,
        allocRewardAmount : allocRewardAmount,
        accRewardAmount : accRewardAmount,
        totalAmount : dsgNft.balanceOf(address(this)),
        nft : address(dsgNft),
        nftSymbol : IERC721Metadata(address(dsgNft)).symbol()
        });
    }

    function updatePool() public {
        if (block.number < startBlock) {
            return;
        }

        uint256 blk = block.number;
        if (blk > endBlock) {
            blk = endBlock;
        }

        if (blk <= lastRewardBlock) {
            return;
        }

        if (accShare == 0) {
            lastRewardBlock = blk;
            return;
        }
        uint256 multiplier = getMultiplier(lastRewardBlock, blk);
        uint256 rewardTokenReward = multiplier.mul(rewardTokenPerBlock);
        accRewardTokenPerShare = accRewardTokenPerShare.add(
            rewardTokenReward.mul(1e12).div(accShare)
        );
        allocRewardAmount = allocRewardAmount.add(rewardTokenReward);
        accRewardAmount = accRewardAmount.add(rewardTokenReward);

        lastRewardBlock = blk;
    }


    function getFullUserInfo(address _user, uint256 slot) public view
    returns (
        uint256 share,
        uint256[] memory nfts,
        uint256 accRewardAmount_,
        uint256 stakeOrinTime,
        uint256 stakeTime
    )
    {
        UserInfo storage user = userInfo[_user];
        share = user.slotInfo[slot].share;
        nfts = user.slotNfts[slot];
        //rewardDebt = user.slotInfo[slot].rewardDebt;
        if (user.slotInfo[slot].originStartTime == 0) {
            stakeOrinTime = 0;
        } else {
            stakeOrinTime = block.timestamp.sub(user.slotInfo[slot].originStartTime);
        }

        if (user.slotInfo[slot].startBlock == 0) {
            stakeTime = 0;
        } else {
            stakeTime = block.number.sub(user.slotInfo[slot].startBlock);
        }

    }

    function getNfts(address _user) public view returns (uint256[] memory ids) {
        UserInfo storage user = userInfo[_user];
        uint256 len = user.nfts.length();

        uint256[] memory ret = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            ret[i] = user.nfts.at(i);
        }
        return ret;
    }

    //领取奖励
    function harvest(uint256 slot) public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.slotInfo[slot].harvestTime != 0 && block.timestamp - user.slotInfo[slot].harvestTime >= harvestLimitTime, "can not withdraw");
        uint256 pending = this.pendingToken(msg.sender, slot);
        //console.log("pending:",pending);
        if (pending > 0) {
            safeTokenTransfer(msg.sender, pending);
        }
        user.slotInfo[slot].startBlock = block.number;
        user.slotInfo[slot].harvestTime = block.timestamp;
    }

    function harvest_internal(uint256 slot) internal {
        UserInfo storage user = userInfo[msg.sender];
        // require(user.slotInfo[slot].harvestTime != 0 && block.timestamp - user.slotInfo[slot].harvestTime >= harvestLimitTime, "can not withdraw");
        uint256 pending = this.pendingToken(msg.sender, slot);
        //console.log("pending:",pending);
        if (pending > 0) {
            safeTokenTransfer(msg.sender, pending);
        }
        user.slotInfo[slot].startBlock = block.number;
        user.slotInfo[slot].harvestTime = block.timestamp;
    }

    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = rewardToken.balanceOf(address(this));
        if (_amount > tokenBal) {
            if (tokenBal >= 0) {
                _amount = tokenBal;
            }
        }

        if (_amount > 0) {
            rewardToken.transfer(_to, _amount.mul(90).div(100));
            if (stealPool != address(0)) {
                rewardToken.transfer(stealPool, _amount.mul(5).div(100));
                stealAmount = stealAmount.add(_amount.mul(5).div(100));
            }
            if (activityPool != address(0)) {
                rewardToken.transfer(activityPool, _amount.mul(5).div(100));
                activityAmount = activityAmount.add(_amount.mul(5).div(100));
            }
        }
    }

    // Withdraw reward. EMERGENCY ONLY.
    function emergencyRewardWithdraw(uint256 _amount) public onlyOwner {
        require(_amount <= rewardToken.balanceOf(address(this)), 'not enough token');
        rewardToken.safeTransfer(address(msg.sender), _amount);
    }

    function setLimitTime(uint256 limitTime_) public onlyOwner {
        limitTime = limitTime_;
    }

    function setHarvestLimitTime(uint256 limitTime_) public onlyOwner {
        harvestLimitTime = limitTime_;
    }

    //pkId 机甲id
    //energy
    //机甲质押
    function batchStake(uint256[] memory tokenIds, uint256[] memory powers, uint256 pkId, uint256 energy, uint256 mineId) public {
        require(tokenIds.length == 5, "wrong amount");
        UserInfo storage user = userInfo[msg.sender];
        require(user.slotNfts[pkId].length == 0, "slot already used");
        require(energy == 7200 || energy == 14400 || energy == 0, "error energy");
        // updatePool();
        uint256 totalPower;
        for (uint i = 0; i < tokenIds.length; i++) {
            // stake_internal(tokenIds[i], powers[i]);
            uint256 tokenId = tokenIds[i];
            dsgNft.safeTransferFrom(
                address(msg.sender),
                address(this),
                tokenId
            );
            user.nfts.add(tokenId);
            nftPower[tokenId] = powers[i];
            totalPower = totalPower.add(powers[i]);
        }
        require(totalPower <= 10000, "wrong power");
        if (totalPower <= 7000) {
            require(mineId <= 1, "wrong mineId");
        } else if (totalPower <= 9000) {
            require(mineId <= 2, "wrong mineId");
        } else {
            require(mineId <= 3, "wrong mineId");
        }


        user.slotInfo[pkId].share = user.slotInfo[pkId].share.add(totalPower);
        user.slots = user.slots.add(1);
        user.slotNfts[pkId] = tokenIds;
        user.slotInfo[pkId].startBlock = block.number;
        user.slotInfo[pkId].harvestTime = block.timestamp;
        user.slotInfo[pkId].originStartTime = block.timestamp;
        user.slotInfo[pkId].mineId = mineId;
        user.slotInfo[pkId].energy = energy;
        StakeWithSlot(msg.sender, pkId, tokenIds, totalPower, energy);
    }

    //赎回机甲
    function withdrawSlot(uint256 slot) public {
        UserInfo storage user = userInfo[msg.sender];
        require(block.timestamp - user.slotInfo[slot].originStartTime >= limitTime, "can not withdraw");
        uint256[] memory tokenIds = user.slotNfts[slot];
        require(tokenIds.length > 0, "no nft");
        harvest_internal(slot);
        user.slots = user.slots.sub(1);
        delete user.slotNfts[slot];
        uint256 totalPower;
        for (uint i = 0; i < tokenIds.length; i++) {
            totalPower = totalPower.add(nftPower[tokenIds[i]]);
            dsgNft.safeTransferFrom(address(this), msg.sender, tokenIds[i]);
            //withdraw(tokenIds[i]);
            user.nfts.remove(tokenIds[i]);
        }
        //  accShare = accShare.sub(totalPower);
        user.slotInfo[slot].share = user.slotInfo[slot].share.sub(totalPower);
        // user.slotInfo[slot].rewardDebt = user.slotInfo[slot].share.mul(accRewardTokenPerShare).div(1e12);
        emit WithdrawSlot(msg.sender, slot);
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


    receive() external payable {
        // assert(msg.sender == WOKT);
        // only accept OKT via fallback from the WOKT contract
    }
}
