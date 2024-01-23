// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IInvitePool.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "hardhat/console.sol";

contract SinglePool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IInvitePool public inviteLayer;
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        bool synced;
        uint256 reward;  //old data
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. Tokens to distribute per block.
        uint256 lastRewardBlock;  // Last block number that Tokens distribution occurs.
        uint256 accRewardsPerShare; // Accumulated RewardTokens per share, times 1e18. See below.
    }

    IERC20 public depositToken;
    IERC20 public rewardToken;

    // uint256 public maxStaking;

    // tokens created per block.
    uint256 public rewardPerBlock;

    // Bonus muliplier for early makers.
    uint256 public BONUS_MULTIPLIER = 1;
    bytes32 public merkleRoot;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;
    mapping(address => uint256) public userTeamReward;
    mapping(address => uint256) public userTeamLevel;
    // Total amount pledged by users
    uint256 public totalDeposit;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 private totalAllocPoint = 0;
    // The block number when mining starts.
    uint256 public startBlock;
    // The block number when mining ends.
    uint256 public bonusEndBlock;

    address  private constant  _teamLeft = 0xc5d516F0d967C3e780Ad4b049cf986837831777A; //团队
    address  private constant _teamEqualLeft = 0xc5d516F0d967C3e780Ad4b049cf986837831777A; //平级
    address  private constant _teamCommunityLeft = 0xc5d516F0d967C3e780Ad4b049cf986837831777A;//社区
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(
        IERC20 _depositToken,
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        depositToken = _depositToken;
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;

        bonusEndBlock = _bonusEndBlock;

        // staking pool
        poolInfo.push(PoolInfo({
        lpToken : _depositToken,
        allocPoint : 1000,
        lastRewardBlock : startBlock,
        accRewardsPerShare : 0
        }));

        totalAllocPoint = 1000;
        // maxStaking = 50000000000000000000;

    }
    function setRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function stopReward() public onlyOwner {
        bonusEndBlock = block.number;
    }

    function setTeamLevel(uint256 _lev, address user) public onlyOwner {
        userTeamLevel[user] = _lev;
    }

    function setTeamLevelRel(uint256 _lev, address user, address _recommend) public onlyOwner {
        inviteLayer.addRecommend(user, _recommend);
        userTeamLevel[user] = _lev;
    }
    //设置邀请合约
    function setInvitePool(address inviteLayer_) public onlyOwner {
        inviteLayer = IInvitePool(inviteLayer_);
    }

//    function setUserAmountTest(address _user, uint256 amount) public onlyOwner {
//        UserInfo storage user = userInfo[_user];
//        user.amount = amount;
//    }


    function getUserTeamLevel(address _user) public view returns (uint256) {
        uint256 _level = userTeamLevel[_user];
        if (_level != 0) {
            return _level;
        }
        UserInfo memory user = userInfo[_user];
        address[] memory users = inviteLayer.getOneLevelLists(_user);
        uint256 one = users.length;
        if (user.amount >= 30000e18) {
            if (one >= 10) {
                uint256 m = 0;
                for (uint256 i = 0; i < one; i++) {
                    if (getUserTeamLevel(users[i]) == 4) {
                        m++;
                    }
                }
                if (m >= 3) {
                    return 5;
                }
            }

        }
        if (user.amount >= 10000e18) {
            if (one >= 10) {
                uint256 m = 0;
                for (uint256 i = 0; i < one; i++) {
                    if (getUserTeamLevel(users[i]) == 3) {
                        m++;
                    }
                }
                if (m >= 3) {
                    return 4;
                }
            }
        }
        if (user.amount >= 5000e18) {
            if (one >= 10) {
                uint256 m = 0;
                for (uint256 i = 0; i < one; i++) {
                    if (getUserTeamLevel(users[i]) == 2) {
                        m++;
                    }
                }
                if (m >= 3) {
                    return 3;
                }

            }
        }
        if (user.amount >= 2000e18) {
            if (one >= 5) {
                uint256 m = 0;
                for (uint256 i = 0; i < one; i++) {
                    if (getUserTeamLevel(users[i]) == 1) {
                        m++;
                    }
                }
                if (m >= 3) {
                    return 2;
                }

            }
        }
        if (user.amount >= 1000e18) {
            if (one >= 5) {
                address[] memory members = inviteLayer.getFiveAllLists(_user);
                uint256 stake = 0;
                uint256 stakeNum = 0;
                for (uint256 i = 0; i < members.length; i++) {
                    if (userInfo[members[i]].amount > 0) {
                        stake = stake.add(userInfo[members[i]].amount);
                        stakeNum++;
                    }
                }
                if (stake >= 15 && stake >= 15000e18) {
                    return 1;
                }

            }
        }
        return 0;


    }


// Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER);
        }
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

// View function to see pending Reward on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[_user];
        uint256 accRewardsPerShare = pool.accRewardsPerShare;
        uint256 lpSupply = totalDeposit;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accRewardsPerShare = accRewardsPerShare.add(tokenReward.mul(1e18).div(lpSupply));
        }
        return user.amount.mul(accRewardsPerShare).div(1e18).sub(user.rewardDebt);
    }

// Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = totalDeposit;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accRewardsPerShare = pool.accRewardsPerShare.add(tokenReward.mul(1e18).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

// Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function pendingOldReward(address _user) external view returns (uint256) {
        //  PoolInfo storage pool = poolInfo[0];
        UserInfo memory user = userInfo[_user];
        return user.reward;
    }

    function pendingTeamReward(address _user) external view returns (uint256) {
        //  PoolInfo storage pool = poolInfo[0];
        // UserInfo memory user = userTeamReward[_user];
        return userTeamReward[_user];
    }

    function setUserTeamReward(address _user, uint256 amount) internal {
        //        console.log("--------setUserTeamReward-----------");
        //        console.log(_user);
        address[] memory uppers = inviteLayer.getUppers(_user);
        if (uppers[0] != address(0)) {
            console.log("直接推荐奖励");
            console.log(amount);
            userTeamReward[uppers[0]] = userTeamReward[uppers[0]].add(amount.mul(20).div(100));
            console.log(amount.mul(20).div(100));
            //直接推荐奖励
        }


        uint256 last = 0;
        uint256 front = getUserTeamLevel(_user);
        uint256 leftTeam = uint256(5);
        uint256 leftEqual = uint256(5);

        for (uint256 i = 0; i < uppers.length; i++) {
            if (uppers[i] != address(0)) {
                uint256 level = getUserTeamLevel(uppers[i]);
                if (level != 0 && level > last) {
                    //0 0 1 1  1
                    //1  3 3 3 3
                    // 1 2 3 4 5
                    //1  0 0 3 3
                    userTeamReward[uppers[i]] = userTeamReward[uppers[i]].add(amount.mul(level.sub(last)).mul(10).div(100));
                    leftTeam = leftTeam.sub(level.sub(last));
                    console.log(level);
                    console.log(last);
                    console.log("团队奖励");
                    console.log(amount.mul(level.sub(last)).mul(10).div(100));
                    //团队奖励
                    last = level;


                }
                //平级奖励
                if (front != 0 && level != 0 && front == level) {
                    userTeamReward[uppers[i]] = userTeamReward[uppers[i]].add(amount.mul(5).div(100));
                    leftEqual = leftEqual.sub(uint256(1));
                    console.log("平级奖励");
                }
                front = level;

            }
        }

        //未分配
        if (leftEqual != 0) {
            userTeamReward[_teamEqualLeft] = userTeamReward[_teamLeft].add(amount.mul(5).mul(leftEqual).div(100));
            console.log(leftEqual);
        }
        if (leftTeam != 0) {
            userTeamReward[_teamLeft] = userTeamReward[_teamLeft].add(amount.mul(10).mul(leftTeam).div(100));
            console.log(leftTeam);
        }
        //社区竞争奖励
        userTeamReward[_teamCommunityLeft] = userTeamReward[_teamCommunityLeft].add(amount.mul(5).div(100));
    }

    function withdrawTeamReward() public {
        uint256 reward = userTeamReward[msg.sender];
        if (reward > 0) {
            uint256 bal = rewardToken.balanceOf(address(this));
            if (bal >= reward) {
                rewardToken.safeTransfer(address(msg.sender), reward);
                userTeamReward[msg.sender] = 0;

            } else {
                rewardToken.safeTransfer(address(msg.sender), bal);
                userTeamReward[msg.sender] = reward.sub(bal);
            }
        }
    }

    function withdrawOld(bytes32[] calldata merkleProof, address _recommend, uint256 reward) public {
        UserInfo storage user = userInfo[msg.sender];
        if (!user.synced) {
            require(MerkleProof.verify(merkleProof, merkleRoot, keccak256(abi.encodePacked(msg.sender, _recommend, reward))), "invalid merkle proof");
            if (_recommend != address(0)) {
                inviteLayer.addRecommend(msg.sender, _recommend);
            }
            user.synced = true;
            if (reward > 0) {
                uint256 bal = rewardToken.balanceOf(address(this));
                if (bal >= reward) {
                    rewardToken.safeTransfer(address(msg.sender), reward);
                    user.reward = 0;
                } else {
                    rewardToken.safeTransfer(address(msg.sender), bal);
                    user.reward = reward.sub(bal);
                }
            }
        } else if (user.synced) {
            if (user.reward > 0) {
                uint256 pending = user.reward;
                uint256 bal = rewardToken.balanceOf(address(this));
                if (bal >= pending) {
                    rewardToken.safeTransfer(address(msg.sender), pending);
                    user.reward = 0;
                } else {
                    rewardToken.safeTransfer(address(msg.sender), bal);
                    user.reward = user.reward.sub(bal);
                }
            }
        }

    }

// Stake tokens to Pool
    function deposit(uint256 _amount, bytes32[] calldata merkleProof, address _recommend, uint256 reward) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[msg.sender];

        if (!user.synced) {
            require(MerkleProof.verify(merkleProof, merkleRoot, keccak256(abi.encode(msg.sender, _recommend, reward))), "invalid merkle proof");
            if (_recommend != address(0)) {
                inviteLayer.addRecommend(msg.sender, _recommend);
            }
            user.reward = reward;
            user.synced = true;
        }

        // require (_amount.add(user.amount) <= maxStaking, 'exceed max stake');

        updatePool(0);

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRewardsPerShare).div(1e18).sub(user.rewardDebt);
            if (pending > 0) {
                setUserTeamReward(address(msg.sender), pending);
                uint256 bal = rewardToken.balanceOf(address(this));
                if (bal >= pending) {
                    rewardToken.safeTransfer(address(msg.sender), pending);
                } else {
                    rewardToken.safeTransfer(address(msg.sender), bal);
                }
            }
        }
        if (_amount > 0) {
            uint256 oldBal = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            _amount = pool.lpToken.balanceOf(address(this)).sub(oldBal);
            user.amount = user.amount.add(_amount);
            totalDeposit = totalDeposit.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardsPerShare).div(1e18);

        emit Deposit(msg.sender, _amount);
    }

// Withdraw tokens from STAKING.
    function withdraw(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accRewardsPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            setUserTeamReward(address(msg.sender), pending);
            uint256 bal = rewardToken.balanceOf(address(this));
            rewardToken.safeTransfer(address(msg.sender), pending);
            if (bal >= pending) {
                rewardToken.safeTransfer(address(msg.sender), pending);
            } else {
                rewardToken.safeTransfer(address(msg.sender), bal);
            }
        }

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            totalDeposit = totalDeposit.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardsPerShare).div(1e18);

        emit Withdraw(msg.sender, _amount);
    }

// Withdraw without caring about rewards. EMERGENCY ONLY.
//    function emergencyWithdraw() public {
//        PoolInfo storage pool = poolInfo[0];
//        UserInfo storage user = userInfo[msg.sender];
//        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
//        if (totalDeposit >= user.amount) {
//            totalDeposit = totalDeposit.sub(user.amount);
//        } else {
//            totalDeposit = 0;
//        }
//        user.amount = 0;
//        user.rewardDebt = 0;
//        emit EmergencyWithdraw(msg.sender, user.amount);
//    }

// Withdraw reward. EMERGENCY ONLY.
    function emergencyRewardWithdraw(uint256 _amount) public onlyOwner {
        require(_amount <= rewardToken.balanceOf(address(this)), 'not enough token');
        rewardToken.safeTransfer(address(msg.sender), _amount);
    }

}