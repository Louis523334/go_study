// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Factory} from "../MySwap/Factory.sol";

contract PoolManager is Factory{
    struct Pair {
        address token0;
        address token1;
    }
    struct PoolInfo {
        address pool;
        address token0;
        address token1;
        uint32 index;
        uint24 fee;
        uint8 feeProtocol;
        int24 tickLower;
        int24 tickUpper;
        int24 tick;
        uint160 sqrtPriceX96;
        uint128 liquidity;
    }

    Pair[] public pairs;

    function getPairs() external view override returns (Pair[] memory) {
        return pairs;
    }

    function getAllPool() external view returns (PoolInfo[] memory poolsInfo) {
        uint32 length = 0;
        // 先算一下大小
        for (uint32 i = 0; i < pairs.length; i++) {
            length += uint32(pools[pairs[i].token0][pairs[i].token1].length);
        }

        // 再填充数据
        poolsInfo = new PoolInfo[](length);
        uint256 index;
        for (uint32 i = 0; i < pairs.length; i++) {
            address[] memory addresses = pools[pairs[i].token0][
                                pairs[i].token1
                ];
            for (uint32 j = 0; j < addresses.length; j++) {
                Pool pool = Pool(addresses[j]);
                poolsInfo[index] = PoolInfo({
                    pool: addresses[j],
                    token0: pool.token0(),
                    token1: pool.token1(),
                    index: j,
                    fee: pool.fee(),
                    feeProtocol: 0,
                    tickLower: pool.tickLower(),
                    tickUpper: pool.tickUpper(),
                    tick: pool.tick(),
                    sqrtPriceX96: pool.sqrtPriceX96(),
                    liquidity: pool.liquidity()
                });
                index++;
            }
        }
        return poolsInfo;
    }

    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable returns (address poolAddress) {
        require(
            params.token0 < params.token1,
            "token0 must be less than token1"
        );

        poolAddress = this.createPool(
        params.token0,
        params.token1,
        params.tickLower,
        params.tickUpper,
        params.fee
    );
        Pool pool = Pool(poolAddress);
        uint256 index = pools[pool.token0()][pool.token1()].length;

        if (pool.sqrtPriceX96() == 0) {
            pool.initialize(params.sqrtPriceX96);

            // index=1且初始价格为0说明是新创建的pool
            if (index == 1) {
                pairs.push(
                Pair({token0: pool.token0(), token1: pool.token1()})
            );
            }
        }
    }
}
