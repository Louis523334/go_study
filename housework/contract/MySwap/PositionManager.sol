// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {PoolManager} from "./PoolManager.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PositionManager {
    PoolManager public poolManager;
    struct PositionInfo {

    }

    uint176 private _nextId = 1;
    constructor(address _poolManger) ERC721("MetaNodeSwapPosition", "MNSP") {
        poolManager = PoolManager(_poolManger);
    }

    // 用一个 mapping 来存放所有 Position 的信息
    mapping(uint256 => PositionInfo) public positions;

    // 获取Position信息
    function getAllAPositions() external view returns (PositionInfo[] memory positionInfo) {
        positionInfo = new PositionInfo[](_nextId - 1);
        for (uint32 i = 0; i < _nextId; i++) {
            positionInfo[i] = positions[i + 1];
        }
}
    function getSender() public view returns (address) {
        return msg.sender;
    }

    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    modifier checkDeadline(uint256 deadline) {
        require(_blockTimestamp() <= deadline, "Transaction too old");
        _;
    }

    function mint(MintParams calldata params) external payable checkDeadline(params.deadline) returns (uint256 position, uint128 liquidity, uint256 amount0, uint256 amount1) {
        // mint 一个 NFT 作为 position 发给 LP
        // NFT 的 tokenId 就是 positionId
        // 通过 MintParams 里面的 token0 和 token1 以及 index 获取对应的 Pool
        // 调用 poolManager 的 getPool 方法获取 Pool 地址
        address _pool = poolManager.getPool(
        params.token0,
        params.token1,
        params.index
    );
        Pool pool = Pool(_pool);

        //
        uint160 sqrtPriceX96 = pool.sqrtPriceX96();
        uint160 sqrtRatioAX96 = TickMath.getSqrtPriceAtTick(pool.tickLower());
        uint160 sqrtRatioBX96 = TickMath.getSqrtPriceAtTick(pool.tickUpper());

        liquidity = LiquidityAmounts.getLiquidityForAmounts(
        sqrtPriceX96,
        sqrtRatioAX96,
        sqrtRatioBX96,
        params.amount0Desired,
        params.amount1Desired
    );
        // data 是 mint 后回调 PositionManager 会额外带的数据
        // 需要 PoistionManger 实现回调，在回调中给 Pool 打钱
        bytes memory data = abi.encode(
        params.token0,
            params.token1,
            params.index,
            msg.sender
    );
        (amount0, amount1) = pool.mint(address(this), liquidity, data);
        _mint(params.recipient, (positionId = _nextId++));
        (
            ,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            ,
        ) = pool.getPosition(address(this));
        positions[positionId] = PositionInfo({
            id: positionId,
            owner: params.recipient,
            token0: params.token0,
            token1: params.token1,
            index: params.index,
            fee: pool.fee(),
            liquidity: liquidity,
            tickLower: pool.tickLower(),
            tickUpper: pool.tickUpper(),
            tokensOwed0: 0,
            tokensOwed1: 0,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128
    });
    }

    modifier isAuthorizedForToken(uint256 tokenId) {
        address owner = ERC721.ownerOf(tokenId);
        require(_isAuthorized(owner, msg.sender, tokenId), "Not approved");
        _;
    }

    function burn(uint256 positionId) external isAuthorizedForToken(positionId) returns (uint256 amount0, uint256 amount1) {
        PositionInfo storage position = positions[positionId];
        uint128 liquidity = position.liquidity;
        address _pool = poolManager.getPool(position.token0, position.token1, position.index);
        Pool pool = Pool(_pool);
        (amount0, amount1) = pool.burn(_liquidity);
        // 计算这部分流动性产生的手续费
        (
        ,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        ,
        ) = pool.getPosition(address(this));

        position.tokensOwed0 += uint128(amount0) +
                                uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 -
                        position.feeGrowthInside0LastX128,
                    position.liquidity,
                    FixedPoint128.Q128
                )
            );
        position.tokensOwed1 +=
            uint128(amount1) +
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 -
                        position.feeGrowthInside1LastX128,
                    position.liquidity,
                    FixedPoint128.Q128
                )
            );
        // 更新 position 的信息
        position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        position.liquidity = 0;
}


    function collect(uint256 positionId, address recipient) external isAuthorizedForToken(positionId) returns (uint256 amount0, uint256 amount1) {
        PositionInfo storage position = positions[positionId];
        address _pool = poolManager.getPool(
            position.token0,
            position.token1,
            position.index
        );
        Pool pool = Pool(_pool);
        (amount0, amount1) = pool.collect(
            recipient,
            position.tokensOwed0,
            position.tokensOwed1
    );
        position.tokensOwed0 = 0;
        position.tokensOwed1 = 0;

        if (position.liquidity == 0) {
            _burn(positionId);
        }
    }
}
