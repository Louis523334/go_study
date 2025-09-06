// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interface/IDebtToken.sol";
import "./library/SafeMath.sol";

contract Pledge is ReentrancyGuard {

    using SafeMath for uint256;

    struct PoolBaseInfo {
        uint256 settleTime;  // 结算时间
        uint256 endTime;  // 结束时间
        uint256 interestRate;  // 提供资金方的利率
        uint256 maxSupply;  // 最大接受的资金数量
        uint256 lendSupply;  // 提供资金数量
        uint256 borrowSupply;  // 抵押资金数量
        uint256 martgageRate;   // 抵押率
        address lendToken;  // 提供资金地址
        address borrowToken;  // 抵押资金地址
        PoolState state;   // 状态 'MATCH, EXECUTION, FINISH, LIQUIDATION, UNDONE'
        IDebtToken spCoin;  // 给提供资金方的凭证
        IDebtToken jpCoin;  // 给抵押资金方的凭证
        uint256 autoLiquidateThreshold; // 自动清算阈值
    }
    PoolBaseInfo[] public pools;

    // 每个池子的数据信息
    struct PoolDataInfo {
        uint256 settleAmountLend;
        uint256 settleAmountBorrow;
        uint256 finishAmountLend;
        uint256 finishAmountBorrow;
        uint256 liquidationAmountLend;
        uint256 liquidationAmountBorrow;
    }
    PoolDataInfo[] public poolData;

    // 用户提供资金信息
    struct LendInfo {
        uint256 stakeAmount;
        uint256 refundAmount;
        bool hasClaim;  // false=未领取凭证, true=已领取凭证, 默认位false
        bool hasRefund; // false=未领取退款, true=已领取退款, 默认位false
    }
    mapping (address user => mapping(uint256 _pid => LendInfo)) public userLendInfo;

    // 用户抵押资金信息
    struct BorrowInfo {
        uint256 stakeAmount;
        uint256 refundAmount;
        bool hasClaim;  // false=未领取凭证, true=已领取凭证, 默认位false
        bool hasRefund; // false=未领取退款, true=已领取退款, 默认位false
    }
    mapping (address user => mapping(uint256 _pid => BorrowInfo)) public userBorrowInfo;

    uint256 constant internal calDecimal = 1e18;
    uint256 constant internal baseDecimal = 1e8;
    uint256 public minAmount = 100e18;
    uint256 constant baseYear = 365 days;

    enum PoolState {MATCH, EXECUTION, FINISH, LIQUIDATION, UNDONE}
    PoolState constant defaultChoice = PoolState.MATCH;

    bool public globalPaused = false;
    // pancake swap router
    address public swapRouter;
    // receiving fee address
    address payable public feeAddress;
    // // oracle address
    // IBscPledgeOracle public oracle;
    // fee
    uint256 public lendFee;
    uint256 public borrowFee;

    // admin
    address public owner;

    // --事件
    // 设置手续费
    event SetFee(uint256 _lendFee, uint256 _borrowFee);
    // 设置swaprouter
    event SetSwapRouterAddress(address _swapRouter);
    // 设置手续费收取地址
    event SetFeeAddress(address _feeAddress);
    // 设置最小资金提供额度
    event SetMinAmount(uint256 _minAmount);
    // 提供资金方出资
    event DepositLend(address indexed from,address indexed token,uint256 amount,uint256 mintAmount);
    // 提供资金方获取凭证
    event ClaimLend(address indexed to,address indexed token,uint256 amount);
    // 抵押资金方获取凭证
    event ClaimBorrow(address indexed to,address indexed token,uint256 amount);
    // 状态改变事件，pid是项目id，beforeState是改变前的状态，afterState是改变后的状态
    event StateChange(uint256 indexed pid, uint256 indexed beforeState, uint256 indexed afterState);
    // 紧急借出提取事件，from是提取者地址，token是提取的代币地址，amount是提取的数量
    event EmergencyLendWithdrawal(address indexed from, address indexed token, uint256 amount);
    // 紧急抵押提取事件，from是提取者地址，token是提取的代币地址，amount是提取的数量
    event EmergencyBorrowWithdrawal(address indexed from, address indexed token, uint256 amount);
    // 提供资金方提取本金加利息事件，from是提取者地址，token是提取的代币地址，amount是提取的数量，burnAmount是销毁的数量
    event WithdrawLend(address indexed from,address indexed token,uint256 amount,uint256 burnAmount);
    // 抵押资金方换回抵押资金事件，from是提取者地址，token是提取的代币地址，amount是提取的数量，burnAmount是销毁的数量
    event WithdrawBorrow(address indexed from,address indexed token,uint256 amount,uint256 burnAmount);
    // 提供资金方提取未使用的资金事件，from是退款者地址，token是退款的代币地址，refund是退款的数量
    event RefundLend(address indexed from, address indexed token, uint256 refund);
    // 质押资金方提取未使用的资金事件，from是退款者地址，token是退款的代币地址，refund是退款的数量
    event RefundBorrow(address indexed from, address indexed token, uint256 refund);

    constructor(
        address _owner,
        address _swapRouter,
        address payable _feeAddress
    ) {
        require(_swapRouter != address(0), "Is zero address");
        require(_feeAddress != address(0), "Is zero address");

        swapRouter = _swapRouter;
        feeAddress = _feeAddress;
        owner = _owner;

        lendFee = 0;
        borrowFee = 0;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "No Access");
        _;
    }

    function setFee(uint256 _lendFee, uint256 _borrowFee) onlyOwner external {
        lendFee = _lendFee;
        borrowFee = _borrowFee;
        emit SetFee(_lendFee, _borrowFee);
    }

    function setSwapRouterAddress(address _swapRouter) onlyOwner external {
        require(_swapRouter != address(0), "Invalid swapRouter address");
        swapRouter = _swapRouter;
        emit SetSwapRouterAddress(_swapRouter);
    }

    function setFeeAddress(address payable _feeAddress) onlyOwner external {
        require(_feeAddress != address(0), "Invalid Fee address");
        feeAddress = _feeAddress;
        emit SetFeeAddress(_feeAddress);
    }

    function setMinAmount(uint256 _minAmount) onlyOwner external {
        minAmount = _minAmount;
        emit SetMinAmount(_minAmount);
    }

    function getPoolLength() public view returns (uint256) {
        return pools.length;
    }

    function _redeem(address to, address token, uint256 amount) internal {

    }

    function redeem(uint256 feeRatio, address token, uint256 amount) internal returns (uint256) {
        uint256 fee = amount.mul(feeRatio);
        if (fee > 0) {
            _redeem(feeAddress, token, fee);
        }

        return amount.sub(fee);
    }

    function getPrice(address token0, address token1) public view returns (uint256[2] memory prices) {
        prices = [uint256(1), uint256(2)];
        return prices;
    }

    // 创建借贷池
    function createPool(
        uint256 _settleTime, uint256 _endTime, uint256 _interestRate, uint256 _maxSupply,
        uint256 _martgageRate, address _lendToken, address _borrowToken, address _spToken,
        address _jpToken, uint256 _autoLiquidateThreshold
    ) onlyOwner external {
        require(_settleTime < _endTime, "Invalid settle time");
        // 需要_jpToken不是零地址
        require(_jpToken != address(0), "createPool:is zero address");
        // 需要_spToken不是零地址
        require(_spToken != address(0), "createPool:is zero address");

        pools.push(PoolBaseInfo({
            settleTime: _settleTime,
            endTime: _endTime,
            interestRate: _interestRate,
            maxSupply: _maxSupply,
            lendSupply:0,
            borrowSupply:0,
            martgageRate: _martgageRate,
            lendToken:_lendToken,
            borrowToken:_borrowToken,
            state: defaultChoice,
            spCoin: IDebtToken(_spToken),
            jpCoin: IDebtToken(_jpToken),
            autoLiquidateThreshold:_autoLiquidateThreshold
        }));

                // 推入池数据信息
        poolData.push(PoolDataInfo({
            settleAmountLend: 0,
            settleAmountBorrow: 0,
            finishAmountLend: 0,
            finishAmountBorrow: 0,
            liquidationAmountLend: 0,
            liquidationAmountBorrow: 0
        }));


    }

    // 获取当前池的状态
    function getPoolState(uint256 _pid) public view returns(uint256) {
        return uint256(pools[_pid].state);
    }

    // 提供资金方存入资金
    function depositLend(uint256 _pid, uint256 _amount) payable external {
        PoolBaseInfo storage pool = pools[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        require(_amount > 0, "amount must greater than 0");
        require(pool.state == defaultChoice, "pool state must be Match");
        require(_amount <= pool.maxSupply.sub(pool.lendSupply), "amount exceeds max supply");
        require(_amount > minAmount, "depositLend too small");

        lendInfo.hasClaim = false;
        lendInfo.hasRefund = false;

        if (pool.lendToken == address(0)) {
            lendInfo.stakeAmount = lendInfo.stakeAmount.add(msg.value);
            pool.lendSupply = pool.lendSupply.add(msg.value);
        } else {
            lendInfo.stakeAmount = lendInfo.stakeAmount.add(_amount);
            pool.lendSupply = pool.lendSupply.add(_amount);
        }
        emit DepositLend(msg.sender, pool.lendToken, _amount, minAmount);

    }

    // 抵押方抵押资金
    function depositBorrow(uint256 _pid, uint256 _amount) payable external {
        PoolBaseInfo storage pool = pools[_pid];
        BorrowInfo storage borrowInfo = userBorrowInfo[msg.sender][_pid];
        require(_amount > 0, "amount must greater than 0");
        require(pool.state == defaultChoice, "pool state must be Match");
        require(_amount > minAmount, "depositLend too small");

        borrowInfo.hasClaim = false;
        borrowInfo.hasRefund = false;

        if (pool.borrowToken == address(0)) {
            borrowInfo.stakeAmount = borrowInfo.stakeAmount.add(msg.value);
            pool.borrowSupply = pool.borrowSupply.add(msg.value);
        } else {
            borrowInfo.stakeAmount = borrowInfo.stakeAmount.add(_amount);
            pool.borrowSupply = pool.borrowSupply.add(_amount);
        }
    }

    // 撮合
    function settle(uint256 _pid) onlyOwner public {
        PoolBaseInfo storage pool = pools[_pid];
        PoolDataInfo storage dataInfo = poolData[_pid];
        require(pool.settleTime > block.timestamp, "Not reached settle time");
        require(pool.state == defaultChoice, "Pool state must be Match");

        // 获取lendToken和borrowToken的实时价格
        uint256[2] memory prices = getPrice(pool.lendToken, pool.borrowToken);

        if (pool.borrowSupply > 0 && pool.lendSupply > 0) {
            uint256 totalValue = pool.borrowSupply.mul(prices[1]).div(prices[0]);
            uint256 actualValue = totalValue.div(pool.martgageRate);
            // borrowToken换算成lendToken后比池子里的lendToken数量少, 则用换算后的值, 反之用池子里的lendToken的数量
            if (actualValue <= pool.lendSupply) {
                dataInfo.settleAmountLend = actualValue;
                dataInfo.settleAmountBorrow = pool.borrowSupply;
            } else {
                dataInfo.settleAmountLend = pool.lendSupply;
                uint256 actualUsedBorrow = pool.lendSupply.mul(prices[0]).div(prices[1]).mul(pool.martgageRate);
                dataInfo.settleAmountBorrow = actualUsedBorrow;
            }
            //  修改池子状态
            pool.state = PoolState.EXECUTION;
            emit StateChange(_pid, uint256(PoolState.MATCH), uint256(PoolState.EXECUTION));
        } else {
            // 没人提供资金或者没人抵押资产
            pool.state = PoolState.UNDONE;
            dataInfo.settleAmountLend = pool.lendSupply;
            dataInfo.settleAmountBorrow = pool.borrowSupply;
            emit StateChange(_pid, uint256(PoolState.MATCH), uint256(PoolState.UNDONE));
        }
    }

    function claimLend(uint256 _pid) nonReentrant external {
        PoolBaseInfo storage pool = pools[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        PoolDataInfo storage dataInfo = poolData[_pid];
        require(lendInfo.hasClaim == false, "already claim");
        require(pool.state == PoolState.EXECUTION, "pool state must be Execution");

        uint256 totalLend = pool.lendSupply;
        uint256 userStaked = lendInfo.stakeAmount;
        uint256 userShare = userStaked.div(totalLend);
        uint256 spAmount = dataInfo.settleAmountLend.mul(userShare);

        pool.spCoin.mint(msg.sender, spAmount);
        lendInfo.hasClaim = true;
        emit ClaimLend(msg.sender, pool.lendToken, spAmount);
    }

    function claimBorrow(uint256 _pid) nonReentrant external {
        PoolBaseInfo storage pool = pools[_pid];
        BorrowInfo storage borrowInfo = userBorrowInfo[msg.sender][_pid];
        PoolDataInfo storage dataInfo = poolData[_pid];

        require(borrowInfo.hasClaim == false, "already claim");
        require(pool.state == PoolState.EXECUTION, "pool state must be Execution");

        uint256 totalBorrow = pool.borrowSupply;
        uint256 userBorrowed = borrowInfo.stakeAmount;
        uint256 userShare = userBorrowed.div(totalBorrow);
        uint256 jpAmount = dataInfo.settleAmountBorrow.mul(userShare);
        // 抵押资产可获得的lendToken数量
        uint256 lendTokenAmount = dataInfo.settleAmountLend.mul(userShare);

        pool.jpCoin.mint(msg.sender, jpAmount);
        borrowInfo.hasClaim = true;

        // 给抵押房lendToken
        _redeem(msg.sender, pool.lendToken, lendTokenAmount);
        emit ClaimBorrow(msg.sender, pool.borrowToken, jpAmount);

    }

    function refundLend(uint256 _pid) nonReentrant external {
        PoolBaseInfo storage pool = pools[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        PoolDataInfo storage dataInfo = poolData[_pid];

        require(lendInfo.hasRefund == false, "already refunded");
        require(pool.lendSupply.sub(dataInfo.settleAmountLend) > 0, "No token to refund");

        uint256 userShare = lendInfo.stakeAmount.div(pool.lendSupply);
        uint256 refundAmount = (pool.lendSupply.sub(dataInfo.settleAmountLend)).mul(userShare);
        _redeem(msg.sender, pool.lendToken, refundAmount);
        lendInfo.hasRefund = true;
        lendInfo.refundAmount = lendInfo.refundAmount.add(refundAmount);

        emit RefundLend(msg.sender, pool.lendToken, refundAmount);
    }

    function refundBorrow(uint256 _pid) nonReentrant external {
        PoolBaseInfo storage pool = pools[_pid];
        BorrowInfo storage borrowInfo = userBorrowInfo[msg.sender][_pid];
        PoolDataInfo storage dataInfo = poolData[_pid];

        require(borrowInfo.hasRefund == false, "already refunded");
        require(pool.borrowSupply.sub(dataInfo.settleAmountBorrow) > 0, "No token to refund");

        uint256 userShare = borrowInfo.stakeAmount.div(pool.borrowSupply);
        uint256 refundAmount = (pool.borrowSupply.sub(dataInfo.settleAmountBorrow)).mul(userShare);
        _redeem(msg.sender, pool.borrowToken, refundAmount);
        borrowInfo.hasRefund = true;
        borrowInfo.refundAmount = borrowInfo.refundAmount.add(refundAmount);
        emit RefundBorrow(msg.sender, pool.borrowToken, refundAmount);
    }

    function emergencyLendWithdraw(uint256 _pid) nonReentrant public {
        PoolBaseInfo storage pool = pools[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];

        require(pool.state == PoolState.UNDONE, "Pool state must be Undone");
        require(lendInfo.stakeAmount > 0, "No pledge");
        require(!lendInfo.hasRefund, "Double refund");

        // 退还资金
        _redeem(msg.sender, pool.lendToken, lendInfo.stakeAmount);
        lendInfo.hasRefund = true;

        emit EmergencyLendWithdrawal(msg.sender, pool.lendToken, lendInfo.stakeAmount);

    }

    function emergencyBorrowWithdraw(uint256 _pid) nonReentrant public {
        PoolBaseInfo storage pool = pools[_pid];
        BorrowInfo storage borrowInfo = userBorrowInfo[msg.sender][_pid];

        require(pool.state == PoolState.UNDONE, "Pool state must be Undone");
        require(borrowInfo.stakeAmount > 0, "No pledge");
        require(!borrowInfo.hasRefund, "Double refund");

        // 退还资金
        _redeem(msg.sender, pool.lendToken, borrowInfo.stakeAmount);
        borrowInfo.hasRefund = true;

        emit EmergencyBorrowWithdrawal(msg.sender, pool.lendToken, borrowInfo.stakeAmount);
    }

    function finish(uint256 _pid) onlyOwner nonReentrant public {
        PoolBaseInfo storage pool = pools[_pid];
        PoolDataInfo storage dataInfo = poolData[_pid];

        require(block.timestamp > pool.endTime, "Not reached finish time");
        require(pool.state == PoolState.EXECUTION, "Pool state must be Execution");

        // 获取借款和贷款的token
        (address token0, address token1) = (pool.borrowToken, pool.lendToken);

        // settle到finish的时间
        uint256 userStakeTime = pool.endTime.sub(pool.settleTime);
        uint256 timeRation = userStakeTime.div(baseYear);

        // 提供资金方应得的利息
        uint256 interest = dataInfo.settleAmountLend.mul(pool.interestRate).mul(timeRation);
        // 提供资金方应收回的全部数量
        uint256 lendAmount = dataInfo.settleAmountLend.add(interest);
        // 平台需要收取手续费, 手续费+lendAmount = sellAmount, 需要卖出borrowToken来获取lendToken
        uint256 sellAmount = lendAmount.mul(1 + lendFee);
        // amountSell = 实际卖出数量, amountIn = 实际换回数量
        (uint256 amountSell, uint256 amountIn) = _sellExactAmount(swapRouter, token0, token1, sellAmount);
        // 验证交换后的金额是否大于等于贷款金额
        require(amountIn >= lendAmount, "finish: Slippage is too high");

        if (amountIn > lendAmount) {
            uint256 feeAmount = amountIn.sub(lendAmount);
            _redeem(feeAddress, pool.lendToken, feeAmount);
            dataInfo.finishAmountLend = amountIn.sub(feeAmount);
        } else {
            // 实际卖出的比应收回的少, 不收手续费
            dataInfo.finishAmountLend = amountIn;
        }

        // 剩余抵押资产
        uint256 remainBorrowAmount = dataInfo.settleAmountBorrow.sub(amountSell);
        // 扣除手续费的borrowToken数量
        uint256 actualBorrowAmount = redeem(borrowFee, pool.borrowToken, remainBorrowAmount);
        dataInfo.finishAmountBorrow = actualBorrowAmount;

        // 改变池子状态
        pool.state = PoolState.FINISH;
        emit StateChange(_pid,uint256(PoolState.EXECUTION), uint256(PoolState.FINISH));


    }

    function liquidate(uint256 _pid) onlyOwner nonReentrant public {
        PoolBaseInfo storage pool = pools[_pid];
        PoolDataInfo storage dataInfo = poolData[_pid];

        require(block.timestamp > pool.settleTime, "Not reached finish time");
        require(pool.state == PoolState.EXECUTION, "Pool state must be Execution");
        require(checkLiquidate(_pid), "Can not be liquidated");

                // 获取借款和贷款的token
        (address token0, address token1) = (pool.borrowToken, pool.lendToken);

        // settle到finish的时间
        uint256 userStakeTime = pool.endTime.sub(pool.settleTime);
        uint256 timeRation = userStakeTime.div(baseYear);

        // 提供资金方应得的利息
        uint256 interest = dataInfo.settleAmountLend.mul(pool.interestRate).mul(timeRation);
        // 提供资金方应收回的全部数量
        uint256 lendAmount = dataInfo.settleAmountLend.add(interest);
        // 平台需要收取手续费, 手续费+lendAmount = sellAmount, 需要卖出borrowToken来获取lendToken
        uint256 sellAmount = lendAmount.mul(1 + lendFee);
        // amountSell = 实际卖出数量, amountIn = 实际换回数量
        (uint256 amountSell, uint256 amountIn) = _sellExactAmount(swapRouter, token0, token1, sellAmount);

        if (amountIn > lendAmount) {
            uint256 feeAmount = amountIn.sub(lendAmount);
            _redeem(feeAddress, pool.lendToken, feeAmount);
            dataInfo.finishAmountLend = amountIn.sub(feeAmount);
        } else {
            // 实际卖出的比应收回的少, 不收手续费
            dataInfo.finishAmountLend = amountIn;
        }

        // 剩余抵押资产
        uint256 remainBorrowAmount = dataInfo.settleAmountBorrow.sub(amountSell);
        // 扣除手续费的borrowToken数量
        uint256 actualBorrowAmount = redeem(borrowFee, pool.borrowToken, remainBorrowAmount);
        dataInfo.finishAmountBorrow = actualBorrowAmount;

        // 改变池子状态
        pool.state = PoolState.LIQUIDATION;
        emit StateChange(_pid,uint256(PoolState.EXECUTION), uint256(PoolState.LIQUIDATION));


    }

    // 检查是否可以settle
    function checkSettle(uint256 _pid) internal returns (bool) {
        PoolBaseInfo storage pool = pools[_pid];
        return block.timestamp > pool.settleTime;
    }

    // 检查是否可以finish
    function checkFinish(uint256 _pid) internal returns (bool) {
        PoolBaseInfo storage pool = pools[_pid];
        return block.timestamp > pool.endTime;
    }

    // 检查是否需要清算
    function checkLiquidate(uint256 _pid) internal returns (bool) {
        PoolBaseInfo storage pool = pools[_pid];
        PoolDataInfo storage dataInfo = poolData[_pid];

        // 获取lendToken和borrowToken的实时价格
        uint256[2] memory prices = getPrice(pool.lendToken, pool.borrowToken);
        // 当前池子settle后的borrowToken数量和lendToken数量
        uint256 lendAmount = dataInfo.settleAmountLend;
        uint256 borrowAmount = dataInfo.settleAmountBorrow;

        // borrowToken换算成lendToken的价值不应该低于某个阈值
        uint256 borrowValueNow = borrowAmount.mul(prices[1]).div(prices[0]);
        // 清算阈值
        uint256 liquidateThreshold = lendAmount.mul(1 + pool.autoLiquidateThreshold);
        return borrowValueNow < liquidateThreshold;
    }

    // 提供资金方收取本金加利息
    function withdrawLend(uint256 _pid, uint256 _spAmount) nonReentrant public {
        PoolBaseInfo storage pool = pools[_pid];
        PoolDataInfo storage dataInfo = poolData[_pid];

        require(pool.state == PoolState.FINISH || pool.state == PoolState.LIQUIDATION, "Pool state must be finish or liquidation");
        // 销毁凭证
        pool.spCoin.burn(msg.sender, _spAmount);

        uint256 totalSpAmount = dataInfo.settleAmountLend;
        // sp份额
        uint256 userShare = _spAmount.div(totalSpAmount);
        if (pool.state == PoolState.FINISH) {
            uint256 lendAmount = dataInfo.finishAmountLend.mul(userShare);
            _redeem(msg.sender, pool.lendToken, lendAmount);
            emit WithdrawLend(msg.sender,pool.lendToken,lendAmount,_spAmount);
        } else {
            uint256 lendAmount = dataInfo.liquidationAmountLend.mul(userShare);
            _redeem(msg.sender, pool.lendToken, lendAmount);
            emit WithdrawLend(msg.sender,pool.lendToken,lendAmount,_spAmount);
        }

    }

    // 抵押资金方换回自己的资金
    function withdrawBorrow(uint256 _pid, uint256 _jpAmount) nonReentrant public {
        PoolBaseInfo storage pool = pools[_pid];
        PoolDataInfo storage dataInfo = poolData[_pid];
        BorrowInfo storage borrowInfo = userBorrowInfo[msg.sender][_pid];

        require(_jpAmount > 0, "No token to withdraw");
        require(pool.state == PoolState.FINISH || pool.state == PoolState.LIQUIDATION, "Pool state must be finish or liquidation");
        // 销毁凭证
        pool.jpCoin.burn(msg.sender, _jpAmount);

        uint256 totalJpAmount = dataInfo.settleAmountBorrow;
        // jp份额
        uint256 userShare = _jpAmount.div(totalJpAmount);
        if (pool.state == PoolState.FINISH) {
            uint256 borrowAmount = dataInfo.finishAmountBorrow.mul(userShare);
            _redeem(msg.sender, pool.borrowToken, borrowAmount);
            emit WithdrawBorrow(msg.sender,pool.borrowToken,borrowAmount,_jpAmount);
        } else {
            uint256 borrowAmount = dataInfo.liquidationAmountBorrow.mul(userShare);
            _redeem(msg.sender, pool.borrowToken, borrowAmount);
            emit WithdrawBorrow(msg.sender,pool.borrowToken,borrowAmount,_jpAmount);
        }

    }

    function _sellExactAmount(address _swapRouter, address token0, address token1, uint256 amountOut) internal returns (uint256, uint256) {
        uint256 actualSell = 0;
        uint256 amountIn = 0;
        return (actualSell, amountIn);
    }

    // 暂停借贷服务
    function setPause() public onlyOwner {
        globalPaused = !globalPaused;
    }

    modifier notPause() {
        require(globalPaused == false, "Stake has been paused");
        _;
    }

    modifier timeBefore(uint256 _pid) {
        require(block.timestamp < pools[_pid].settleTime, "Less than this time");
        _;
    }

    modifier timeAfter(uint256 _pid) {
        require(block.timestamp > pools[_pid].settleTime, "Greate than this time");
        _;
    }


    modifier stateMatch(uint256 _pid) {
        require(pools[_pid].state == PoolState.MATCH, "state: Pool status is not equal to match");
        _;
    }

    modifier stateNotMatchUndone(uint256 _pid) {
        require(pools[_pid].state == PoolState.EXECUTION || pools[_pid].state == PoolState.FINISH || pools[_pid].state == PoolState.LIQUIDATION,"state: not match and undone");
        _;
    }

    modifier stateFinishLiquidation(uint256 _pid) {
        require(pools[_pid].state == PoolState.FINISH || pools[_pid].state == PoolState.LIQUIDATION,"state: finish liquidation");
        _;
    }

    modifier stateUndone(uint256 _pid) {
        require(pools[_pid].state == PoolState.UNDONE,"state: state must be undone");
        _;
    }



}