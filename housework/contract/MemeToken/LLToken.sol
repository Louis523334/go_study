// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LLToken is ERC20{

    // 每个用户的交税数量
    mapping(address taxPayer => uint256 amount) private _taxMapper;
    // 用户当天交易数量
    mapping(address => UserInfo) private _txCountToday;
    // 税率
    uint8 private _taxRate = 3;
    // 总税额
    uint256 private _totalTax;
    // 当日最大交易数量
    uint256 private _maxTxAmount = 1000 * decimals();
    // 当日允许最大交易次数
    uint256 private _maxTxPerDay = 5;
    struct UserInfo {
        // 上次交易时间
        uint256 lastTxDay;
        // 当日交易次数
        uint256 txCount;
    }
    // tokenA
    IERC20 public immutable tokenA;
    // tokenB
    IERC20 public immutable tokenB;
    // 流动池tokenA数量
    uint256 private reserveA;
    // 流动池tokenB数量
    uint256 private reserveB;

    constructor(address _tokenA, address _tokenB, string memory lpName, string memory lpSymbol) ERC20(lpName, lpSymbol) {
        require(_tokenA != _tokenB, "Tokens must be different");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }


    modifier onlyOwner() {
        // todo: 添加权限验证
        _;
    }
//    实现交易税机制，对每笔代币交易征收一定比例的税费，并将税费分配给特定的地址或用于特定的用途


    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 tax = (amount * _taxRate) / 100;
        uint256 totalAmount = tax + amount;
        require(balanceOf(msg.sender) >= totalAmount, "Not enough balance including tax");
        // 检查转账次数和转账最大数额
        _transferCheck(msg.sender, amount);
        // 转钱给用户
        _transfer(msg.sender, recipient, amount);
        // 收手续费
        _transfer(msg.sender, address(this), tax);
        return true;
    }
//    设置合理的交易限制，如单笔交易最大额度、每日交易次数限制等，防止恶意操纵市场
    function _transferCheck(address from, uint256 amount) private {
        require(amount < _maxTxAmount, "Exceeds max transaction amount");
        uint256 today = block.timestamp / 1 days;
        UserInfo storage u = _txCountToday[from];
        if (u.lastTxDay < today) {
            u.lastTxDay = today;
            u.txCount = 0;
        }
        require(u.txCount < _maxTxPerDay, "Daily transaction limit reached");
        u.txCount++;
    }


    function setTaxRate(uint8 taxRate) public onlyOwner {
        require(taxRate <= 100, "Tax too high");
        _taxRate = taxRate;
    }

    function getTaxRate() public view returns (uint8) {
        return _taxRate;
    }

    function getMaxTxAmount() public view returns (uint256) {
        return _maxTxAmount;
    }

    function setMaxTxAmount(uint256 amount) public onlyOwner {
        _maxTxAmount = amount;
    }

    function getMaxTxPerDay() public view returns (uint256) {
        return _maxTxPerDay;
    }

    function setMaxTxPerDay(uint256 day) public onlyOwner {
        _maxTxPerDay = day;
    }

    // 查看流动性池子A和B的存量
    function getReserves() public view returns (uint256 _reserveA, uint256 _reserveB) {
        _reserveA = reserveA;
        _reserveB = reserveB;
    }

    //    设计并实现与流动性池的交互功能，支持用户向流动性池添加和移除流动性
    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (uint256 _reserveA, uint256 _reserveB) = getReserves();
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            // 初始加入流动性，不做比例约束
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            // 为了不改变价格，需要按池子现有比例提供
            // amountBOptimal = amountADesired * reserveB / reserveA
            uint256 amountBOptimal = (uint256(_reserveB) * amountADesired) / uint256(_reserveA);
            if (amountBOptimal <= amountBDesired) {
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                // 否则按 amountBDesired 计算 amountAOptimal
                uint256 amountAOptimal = (uint256(_reserveA) * amountBDesired) / uint256(_reserveB);
                require(amountAOptimal <= amountADesired, "insufficient A provided");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        require(amountA >= amountAMin && amountB >= amountBMin, "slippage exceeded");

        // Transfer tokens from provider
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        // mint LP tokens
        if (_totalSupply == 0) {
            // 初始流动性：铸造 sqrt(amountA * amountB)
            liquidity = _sqrt(amountA * amountB);
            require(liquidity > 0, "insufficient liquidity minted");
            _mint(msg.sender, liquidity);
        } else {
            // 按比例铸造： liquidity = amountA * totalSupply / reserveA
            liquidity = (amountA * _totalSupply) / uint256(_reserveA);
            require(liquidity > 0, "insufficient liquidity minted");
            _mint(msg.sender, liquidity);
        }

        // 更新储备
        _updateReserves();

//        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external returns (uint256 amountA, uint256 amountB){
        require(liquidity > 0, "liquidity = 0");
        uint256 _totalSupply = totalSupply();
        require(_totalSupply > 0, "no liquidity");

        (uint256 _reserveA, uint256 _reserveB) = getReserves();

        // 计算按份额应得金额
        amountA = (_reserveA * liquidity) / _totalSupply;
        amountB = (_reserveB * liquidity) / _totalSupply;

        require(amountA >= amountAMin && amountB >= amountBMin, "slippage exceeded");

        // Burn LP token from sender
        _burn(msg.sender, liquidity);

        // Transfer underlying tokens to sender
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        _updateReserves();

//        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function _updateReserves() internal {
        uint256 balA = tokenA.balanceOf(address(this));
        uint256 balB = tokenB.balanceOf(address(this));

        require(balA <= type(uint256).max && balB <= type(uint256).max, "balance overflow");
        reserveA = balA;
        reserveB = balB;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y == 0) return 0;
        uint256 x = y / 2 + 1;
        z = y;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    }

    function swapAForB(uint256 amountIn, uint256 amountOutMin) external returns (uint256 amountOut) {
        require(amountIn > 0, "amountIn = 0");
        require(reserveA > 0 && reserveB > 0, "empty pool");

        // 将 tokenA 从用户转到池子
        tokenA.transferFrom(msg.sender, address(this), amountIn);

        // 手续费：假设 0.3% = 3/1000
        uint256 amountInWithFee = amountIn * (1000 - _taxRate);
        amountOut = (amountInWithFee * reserveB) / (reserveA * 1000 + amountInWithFee);

        require(amountOut >= amountOutMin, "slippage exceeded");

        // 发出 tokenB 给用户
        tokenB.transfer(msg.sender, amountOut);

        // 更新储备
        _updateReserves();
    }

    function swapBForA(uint256 amountIn, uint256 amountOutMin) external returns (uint256 amountOut) {
        require(amountIn > 0, "amountIn = 0");
        require(reserveA > 0 && reserveB > 0, "empty pool");

        // 将 tokenB 从用户转到池子
        tokenB.transferFrom(msg.sender, address(this), amountIn);

        // 手续费：0.3%
        uint256 amountInWithFee = amountIn * (1000 - _taxRate);
        amountOut = (amountInWithFee * reserveA) / (reserveB * 1000 + amountInWithFee);

        require(amountOut >= amountOutMin, "slippage exceeded");

        // 发出 tokenA 给用户
        tokenA.transfer(msg.sender, amountOut);

        // 更新储备
        _updateReserves();
    }


}
