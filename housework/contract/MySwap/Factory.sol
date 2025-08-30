// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./Pool.sol";

contract Factory {
    mapping(address => mapping(address => address[])) public pools;
    address[] public allPools;
    struct Parameters {
        address factory;
        address tokenA;
        address tokenB;
        int24 tickLower;
        int24 tickUpper;
        uint24 fee;
    }
    Parameters public parameters;

    event PoolCreated(address indexed token0, address indexed token1, int24 tickLower, int24 tickUpper, uint24 fee, address pool);

    function createPool(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external returns (address pool) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        // 获取当前有得token0, token1池子
        address[] memory existingPools = pools[token0][token1];

        // 检测池子是否已经存在
        for (uint256 i = 0; i < existingPools.length; i++) {
            Pool currentPool = Pool(existingPools[i]);
            if (
            currentPool.tickLower() == tickLower && currentPool.tickUpper() == tickUpper && currentPool.fee() == fee
            ) {
                return existingPools[i];
            }
        }

        parameters = Parameters(
            address(this),
            token0,
            token1,
            tickLower,
            tickUpper,
            fee
        );
        bytes32 key = keccak256(abi.encode(token0, token1, tickLower, tickUpper, fee));

        Pool pool = new Pool{salt: key}();
        address poolAddr = address(pool);
        pools[token0][token1].push(poolAddr);
        delete parameters;
        return pool;

        emit PoolCreated(token0, token1, tickLower, tickUpper, fee, poolAddr);

    }

    function getPool(address tokenA, address tokenB, uint32 index) external returns (address) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");
        // Declare token0 and token1
        address token0;
        address token1;

        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        return pools[token0][token1][index];
    }


    function parameter() external  view returns(address, address, address, int24, int24, uint24) {
        return (parameters.factory, parameters.tokenA, parameters.tokenB, parameters.tickLower, parameters.tickUpper, parameters.fee);
    }
}