// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SqrtPriceMath} from "./libraries/SqrtPriceMath.sol";
import {LiquidityMath} from "./libraries/LiquidityMath.sol";
import {TickMath} from "./libraries/TickMath.sol";
import {SwapRouter} from "./SwapRouter.sol";
import {TransferHelper} from "./libraries/TransferHelper.sol";
import {FixedPoint128} from "./libraries/FixedPoint128.sol";
import {SwapMath} from "./libraries/SwapMath.sol";


contract Pool {
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    int24 public immutable tickLower;
    int24 public immutable tickUpper;
    uint24 public immutable fee;

    uint160 public  sqrtPriceX96;
    int24 public  tick;
    uint128 public  liquidity;
    uint256 public  feeGrowthGlobal0X128;
    uint256 public  feeGrowthGlobal1X128;

    struct Position {
        // 该 Position 拥有的流动性
        uint128 liquidity;
        // 可提取的 token0 数量
        uint128 tokensOwed0;
        // 可提取的 token1 数量
        uint128 tokensOwed1;
        // 上次提取手续费时的 feeGrowthGlobal0X128
        uint256 feeGrowthInside0LastX128;
        // 上次提取手续费是的 feeGrowthGlobal1X128
        uint256 feeGrowthInside1LastX128;
    }

    mapping(address => Position) public positions;
    event Mint(address pool, address recipient, uint128 amount, uint256 amount0, uint256 amount1);
    event Burn(address pool, uint128 amount, uint256 amount0, uint256 amount1);
    event Collect(address, address, uint256 amount0, uint256 amount1);
    event Swap(address, address, uint256 amount0, uint256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick);

    constructor() {
        (factory, token0, token1, tickLower, tickUpper, fee) = Factory(
            msg.sender
        ).parameter();
    }

    function getPosition(address owner) public view returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
    ) {
        return (
            positions[owner].liquidity,
            positions[owner].feeGrowthInside0LastX128,
            positions[owner].feeGrowthInside1LastX128,
            positions[owner].tokensOwed0,
            positions[owner].tokensOwed1
        );
    }

    function balance0() private view returns (uint256) {
        (bool success, bytes memory data) = token0.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    } 

    function balance1() private view returns (uint256) {
        (bool success, bytes memory data) = token1.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function _modifyPosition(address owner, int128 liquidityDelta) private returns (int256 amount0, int256 amount1) {
        amount0 = SqrtPriceMath.getAmount0Delta(
        sqrtPriceX96,
        TickMath.getSqrtPriceAtTick(tickUpper),
        liquidityDelta
    );
        amount1 = SqrtPriceMath.getAmount1Delta(
            TickMath.getSqrtPriceAtTick(tickLower),
            sqrtPriceX96,
            liquidityDelta
        );
        Position storage position = positions[owner];

        // 提取手续费
        uint128 tokensOwed0 = uint128(
        FullMath.mulDiv(
            feeGrowthGlobal0X128 - position.feeGrowthInside0LastX128,
            position.liquidity,
            FixedPoint128.Q128
    )
    );
        uint128 tokensOwed1 = uint128(
            FullMath.mulDiv(
                feeGrowthGlobal1X128 - position.feeGrowthInside1LastX128,
                position.liquidity,
                FixedPoint128.Q128
            )
        );

        // 更新手续费记录
        position.feeGrowthInside0LastX128 = feeGrowthGlobal0X128;
        position.feeGrowthInside1LastX128 = feeGrowthGlobal1X128;

        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            position.tokensOwed0 += tokensOwed0;
            position.tokensOwed1 += tokensOwed1;
        }
        // 修改liquidity
        position.liquidity = LiquidityMath.addDelta(
        position.liquidity,
        liquidityDelta
    );
    }

    function mint(
        address recipient,
        uint256 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1) {
        require(amount > 0, "ZERO_LIQUIDITY");

        (int256 amount0Int, int256 amount1Int) = _modifyPosition(recipient, amount);
        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        // 将token转给pool合约
        mintCallBack(amount0, amount1, data);
        //
        if (amount0 > 0)
            require(balance0Before.add(amount0) <= balance0(), "M0");
        if (amount1 > 0)
            require(balance1Before.add(amount1) <= balance1(), "M1");
        emit Mint(msg.sender, recipient, amount, amount0, amount1);

    }

    function mintCallBack(uint256 amount0, uint256 amount1, bytes calldata data) private {
        (address token0, address token1, uint24 feeTier, address payer) = abi.decode(
            data, (address, address, uint24, address)
        );
//        address _pool = poolManager.getPool(token0, token1, feeTier);
        if (amount0 > 0) {
            IERC20(token0).transferFrom(payer, msg.sender, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transferFrom(payer, msg.sender, amount1);
        }
    }

    function burn(uint128 amount) external returns (uint256 amount0, uint256 amount1) {
        require(amount > 0, "Burn amount must be greater than 0");
        require(
            amount <= positions[msg.sender].liquidity,
            "Burn amount exceeds liquidity"
        );
        // 修改position中的信息
        (int256 amount0Int, int256 amount1Int) = _modifyPosition(
        msg.sender, -int128(amount)
        );
        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (
                positions[msg.sender].tokensOwed0,
                positions[msg.sender].tokensOwed1
            ) = (
                positions[msg.sender].tokensOwed0 + uint128(amount0),
                positions[msg.sender].tokensOwed1 + uint128(amount1)
            );
        }
        emit Burn(msg.sender, amount, amount0, amount1);
    }

    function collect(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint256 amount0, uint256 amount1) {
        Position storage position = positions[msg.sender];

        // 把钱退给用户
        amount0 = amount0Requested > position.tokensOwed0 ? position.tokensOwed0 : amount0Requested;
        amount1 = amount1Requested > position.tokensOwed1 ? position.tokensOwed1 : amount1Requested;

        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }
        emit Collect(msg.sender, recipient, amount0, amount1);

    }

    // 交易中需要临时存储的变量
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the global fee growth of the input token
        uint256 feeGrowthGlobalX128;
        // 该交易中用户转入的 token0 的数量
        uint256 amountIn;
        // 该交易中用户转出的 token1 的数量
        uint256 amountOut;
        // 该交易中的手续费，如果 zeroForOne 是 ture，则是用户转入 token0，单位是 token0 的数量，反正是 token1 的数量
        uint256 feeAmount;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0,int256 amount1) {
        require(amountSpecified != 0, "AS");
        // zeroForOne: 如果从 token0 交换 token1 则为 true，从 token1 交换 token0 则为 false
        require(
            zeroForOne ? sqrtPriceLimitX96 < sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE :
                         sqrtPriceLimitX96 > sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE,
            "SPL"
        );

        // amountSpecified 大于 0 代表用户指定了 token0 的数量，小于 0 代表用户指定了 token1 的数量
        bool exactInput = amountSpecified > 0;
        SwapState memory state = SwapState(
    {
        amountSpecifiedRemainging: amountSpecified,
        amountCalculated: 0,
        sqrtPriceX96: sqrtPriceX96,
        feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
        amountIn: 0,
        amountOut: 0,
        feeAmount: 0
    }
    );
        // 计算交易的上下限，基于 tick 计算价格
        uint160 sqrtPriceX96Lower = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceX96Upper = TickMath.getSqrtPriceAtTick(tickUpper);
        // 计算用户交易价格的限制，如果是 zeroForOne 是 true，说明用户会换入 token0，会压低 token0 的价格（也就是池子的价格），所以要限制最低价格不能超过 sqrtPriceX96Lower
        uint160 sqrtPriceX96PoolLimit = zeroForOne ? sqrtPriceX96Lower : sqrtPriceX96Upper;

        (
        state.sqrtPriceX96,
        state.amountIn,
        state.amountOut,
        state.feeAmount
        ) = SwapMath.computeSwapStep(
        sqrtPriceX96,
            (
            zeroForOne ? sqrtPriceX96PoolLimit < sqrtPriceLimitX96 : sqrtPriceX96PoolLimit > sqrtPriceLimitX96
            )
            ? sqrtPriceLimitX96 : sqrtPriceX96PoolLimit,
        liquidity,
        amountSpecified,
        fee
        );

        // 更新新得价格
        sqrtPriceX96 = state.sqrtPriceX96;
        tick = TickMath.getTickAtSqrtPrice(state.sqrtPriceX96);

        // 计算手续费
        state.feeGrowthGlobalX128 += FullMath.mulDiv(
                state.feeAmount,
                FixedPoint128.Q128,
                liquidity
    );
        // 更新手续费相关信息
        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
        }

        // 计算交易后用户手里的 token0 和 token1 的数量
        if (exactInput) {
            state.amountSpecifiedRemaining -= (state.amountIn + state.feeAmount).toInt256();
            state.amountCalculated = state.amountCalculated.sub(state.amountOut.toInt256());
        } else {
            state.amountSpecifiedRemaining += state.amountOut.toInt256();
            state.amountCalculated = state.amountCalculated.add(
                (state.amountIn + state.feeAmount).toInt256()
            );
        }

        (amount0, amount1) = zeroForOne == exactInput
        ? (
        amountSpecified - state.amountSpecifiedRemaining,
        state.amountCalculated
    )
        :
    (
        state.amountCalculated,
        amountSpecified - state.amountSpecifiedRemaining
    );

        if (zeroForOne) {
            // 需要给 Pool 转入 token0
            uint256 balance0Before = balance0();
            // 转账
            require(balance0Before.add(uint256(amount0)) <= balance0(), "IIA");

            // 转token给用户
            if (amount1 < 0)
                TransferHelper.safeTransfer(
                    token1,
                    recipient,
                    uint256(-amount1)
                );
        } else {
            uint256 balance1Before = balance1();
            SwapRouter(msg.sender).swapCallback(amount0, amount1, data);
            require(balance1Before.add(uint256(amount1)) <= balance1(), "IIA");

            // 转token给用户
            if (amount0 < 0) {
                TransferHelper.safeTransfer(
                    token0,
                    recipient,
                    uint256(-amount0)
                );
            }
        }
        emit Swap(
            msg.sender,
            recipient,
            amount0,
            amount1,
            sqrtPriceX96,
            liquidity,
            tick
        );

    }


}