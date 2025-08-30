// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract MyStake is UUPSUpgradeable, AccessControlUpgradeable {
//    bytes32 public constant UPGRADER_ROLE = keccak256("ADMIN");


    uint256 private constant ACC_PRECISION = 1e30;

    struct PoolInfo {
        IERC20 stakeToken;
        uint256 poolWeight;
        uint256 minDepositAmount;
        uint256 unstakeLockedBlocks;
        uint256 accRewardPerShare;
        uint256 totalStaked;
        uint256 lastRewardBlock;
        bool exists;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct UnstakeRequest {
        uint256 amount;
        uint256 unlockBlock;
        bool withdrawn;
    }

    IERC20 public rewardToken;
    uint256 public rewardPerBlock;

    PoolInfo[] public pools;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(uint256 => mapping(address => UnstakeRequest[])) public unstakeRequests;
    uint256 public totalPoolWeight;

    // events
    event PoolAdded(uint256 indexed pid, address indexed token, uint256 weight);
    event PoolUpdated(uint256 indexed pid, uint256 weight);
    event Staked(address indexed user, uint256 indexed pid, uint256 amount);
    event UnstakeRequested(address indexed user, uint256 indexed pid, uint256 amount, uint256 unlockBlock);
    event Unstaked(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardClaimed(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPerBlockUpdated(uint256 newRate);

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }

    function initialize(IERC20 _rewardToken, uint256 _rewardPerBlock, address admin) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function addPool(
        IERC20 _stakeToken,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) external onlyAdmin {
        require(address(_stakeToken) != address(0), "zero token");
        require(_poolWeight > 0, "weight>0");

        PoolInfo memory p = PoolInfo({
            stakeToken: _stakeToken,
            poolWeight: _poolWeight,
            minDepositAmount: _minDepositAmount,
            unstakeLockedBlocks: _unstakeLockedBlocks,
            accRewardPerShare: 0,
            totalStaked: 0,
            lastRewardBlock: block.number,
            exists: true
    });
        pools.push(p);
        totalPoolWeight += _poolWeight;
        emit PoolAdded(pools.length - 1, address(_stakeToken), _poolWeight);

    }

    function updatePool(
        uint256 pid,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) external onlyAdmin {
        require(pid < pools.length, "invalid pid");
        PoolInfo storage p = pools[pid];
        require(p.exists, "pool not exists");

        totalPoolWeight = totalPoolWeight + _poolWeight -p.poolWeight;
        p.poolWeight = _poolWeight;
        p.minDepositAmount = _minDepositAmount;
        p.unstakeLockedBlocks = _unstakeLockedBlocks;

        emit PoolUpdated(pid, _poolWeight);
    }

    function poolLength() external view returns (uint256) {
        return pools.length;
    }

    function _updatePoolReward(uint256 pid) internal {
        PoolInfo storage p = pools[pid];
        if (block.number <= p.lastRewardBlock) {
            return;
        }
        if (p.totalStaked == 0 || totalPoolWeight == 0) {
            p.lastRewardBlock = block.number;
            return;
        }

        uint256 blocks = block.number - p.lastRewardBlock;
        uint256 poolReward = rewardPerBlock * blocks * p.poolWeight /totalPoolWeight;
        p.accRewardPerShare += (poolReward * ACC_PRECISION) / p.totalStaked;
        p.lastRewardBlock = block.number;
    }

    function pendingReward(uint256 pid, address user) public view returns (uint256) {
        PoolInfo storage p = pools[pid];
        UserInfo storage u = userInfo[pid][user];
        uint256 acc = p.accRewardPerShare;
        if (block.number > p.lastRewardBlock && p.totalStaked !=0 && totalPoolWeight != 0) {
            uint256 blocks = block.number - p.lastRewardBlock;
            uint256 poolReward = rewardPerBlock * blocks * p.poolWeight /totalPoolWeight;
            acc += (poolReward * ACC_PRECISION) / p.totalStaked;
        }
        return (u.amount * acc) / ACC_PRECISION - u.rewardDebt;
    }

    function stake(uint256 pid, uint256 amount) external {
        require(pid < pools.length, "invalid pid");
        PoolInfo storage p = pools[pid];
        require(p.exists, "pool not exists");
        require(amount > 0, "amounnt > 0");
        require(amount >= p.minDepositAmount, "below min deposit");

        _updatePoolReward(pid);
        UserInfo storage user = userInfo[pid][msg.sender];

        if (user.amount > 0) {
            uint256 pending = (user.amount * p.accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
            if (pending > 0) {
                _safeRewardTransfer(msg.sender, pending);
                emit RewardClaimed(msg.sender, pid, pending);
            }
        }
        p.stakeToken.transferFrom(msg.sender, address(this), amount);
        user.amount += amount;
        p.totalStaked += amount;
        user.rewardDebt = (user.amount * p.accRewardPerShare) / ACC_PRECISION;

        emit Staked(msg.sender, pid, amount);
    }

    function requestUnstake(uint256 pid, uint256 amount) external {
        require(pid < pools.length, "invalid pid");
        PoolInfo storage p = pools[pid];
        require(p.exists, "pool not exists");
        require(amount > 0, "amount>0");

        UserInfo storage user = userInfo[pid][msg.sender];
        require(user.amount >= amount, "insufficient staked");

        _updatePoolReward(pid);

        uint256 pending = (user.amount * p.accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
        if (pending > 0) {
            _safeRewardTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, pid, pending);
        }

        user.amount -= amount;
        p.totalStaked -= amount;
        user.rewardDebt = (user.amount * p.accRewardPerShare) / ACC_PRECISION;
        uint256 unlockBlock = block.number + p.unstakeLockedBlocks;
        unstakeRequests[pid][msg.sender].push(UnstakeRequest({amount: amount, unlockBlock: unlockBlock, withdrawn: false}));
        emit UnstakeRequested(msg.sender, pid, amount, unlockBlock);
    }

    function withdrawUnstaked(uint256 pid) external {
        require(pid < pools.length, "invalid pid");
        UnstakeRequest[] storage reqs = unstakeRequests[pid][msg.sender];
        uint256 totalToWithdraw = 0;
        for (uint256 i = 0; i < reqs.length; ++i) {
            UnstakeRequest storage r = reqs[i];
            if (!r.withdrawn && block.number >= r.unlockBlock) {
                totalToWithdraw += r.amount;
                r.withdrawn = true;
            }
        }
        require(totalToWithdraw > 0, "nothing to withdraw");
        PoolInfo storage p = pools[pid];
        p.stakeToken.transfer(msg.sender, totalToWithdraw);
        emit Unstaked(msg.sender, pid, totalToWithdraw);
    }

    function claim(uint256 pid) external {
        require(pid < pools.length, "invalid pid");
        PoolInfo storage p = pools[pid];
        require(p.exists, "pool not exists");

        _updatePoolReward(pid);

        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 pending = user.amount * p.accRewardPerShare / ACC_PRECISION - user.rewardDebt;
        require(pending > 0, "no rewards");

        user.rewardDebt = user.amount * p.accRewardPerShare / ACC_PRECISION;
        _safeRewardTransfer(msg.sender, pending);
        emit RewardClaimed(msg.sender, pid, pending);
    }

    // ADMIN ACTIONS
    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyAdmin {
        rewardPerBlock = _rewardPerBlock;
        emit RewardPerBlockUpdated(_rewardPerBlock);
    }

    function _safeRewardTransfer(address to, uint256 amount) internal {
        uint256 bal = rewardToken.balanceOf(address(this));
        if (amount > bal) {
            amount = bal;
        }
        if (amount > 0) {
            rewardToken.transfer(to, amount);
        }
    }

}
