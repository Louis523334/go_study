// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import {LibOrder, OrderKey} from "./library/LibOrder.sol";
import {RedBlackTreeLibrary, Price} from "./library/RedBlackTreeLibrary.sol";
import "./EasySwapVault.sol";
import {OrderStorage} from "./OrderStorage.sol";
import "./OrderValidator.sol";
import "./library/SafeTransferETH.sol";

contract EasySwapOrderBook is OrderStorage, OrderValidator {

    using SafeTransferETH for address payable;

    address payable private _vault;
    uint128 private protocolShare = 3;

    event LogSkipOrder(OrderKey orderKey, uint64 salt);

    function _makeOrderTry(
        LibOrder.Order calldata order,
        uint256 ETHAmount
    ) internal returns (OrderKey newOrderKey) {
        // 检查订单是否符合需求
        if (
            order.maker == msg.sender &&
            Price.unwrap(order.price) != 0 &&
            order.salt != 0 &&
            (order.expiry > block.timestamp || order.expiry == 0)
        ) {
            newOrderKey = LibOrder.hash(order);
            // 存入资产到金库
            if (order.side == LibOrder.Side.List) {
                if (order.nft.amount != 1) {
                    return LibOrder.ORDERKEY_SENTINEL;
                }
                EasySwapVault(_vault).depositNFT(
                    newOrderKey,
                    order.maker,
                    order.nft.collection,
                    order.nft.tokenId
                );
            } else if (order.side == LibOrder.Side.Bid) {
                if (order.nft.amount == 0) {
                    return LibOrder.ORDERKEY_SENTINEL;
                }
                EasySwapVault(_vault).depositETH{value: uint256(ETHAmount)}(
                    newOrderKey,
                    ETHAmount
                );
            }
            _addOrder(order);
        } else {
            emit LogSkipOrder(LibOrder.hash(order), order.salt);
        }
        
    }

    function _cancelOrderTry(
        OrderKey orderKey
    ) internal returns (bool success) {
        LibOrder.Order memory order = orders[orderKey].order;
        if (
            order.maker == msg.sender 
        ) {
            _removeOrder(order);
            // 把nft从金库中取出
            if (order.side == LibOrder.Side.List) {
                EasySwapVault(_vault).withdrawNFT(
                    orderKey,
                    order.maker,
                    order.nft.collection,
                    order.nft.tokenId
                );
            } else if (order.side == LibOrder.Side.Bid) {
                uint256 availNFTAmount = order.nft.amount - filledAmount[orderKey];
                EasySwapVault(_vault).withdrawETH(
                    orderKey,
                    Price.unwrap(order.price) * availNFTAmount,
                    order.maker
                );
            }
            _cancelOrder(orderKey);
            success = true;
        } else {
            emit LogSkipOrder(orderKey, order.salt);
        }
    }

    function _editOrderTry(
        OrderKey oldOrderKey,
        LibOrder.Order calldata newOrder
    ) internal returns (OrderKey newOrderKey, uint256 deltaBidPrice) {
        LibOrder.Order memory oldOrder = orders[oldOrderKey].order;
        // 检查订单, 只有价格和数量能修改
        if (
            oldOrder.saleKind != newOrder.saleKind || 
            oldOrder.side != newOrder.side || 
            oldOrder.nft.collection != newOrder.nft.collection ||
            oldOrder.maker != newOrder.maker ||
            oldOrder.nft.tokenId != newOrder.nft.tokenId ||
            filledAmount[oldOrderKey] >= oldOrder.nft.amount
        ) {
            emit LogSkipOrder(oldOrderKey, oldOrder.salt);
            return (LibOrder.ORDERKEY_SENTINEL, 0);
        }

        // 检查新订单是否符合要求
        if (
            newOrder.maker != msg.sender ||
            newOrder.salt == 0 ||
            (newOrder.expiry < block.timestamp && newOrder.expiry != 0)) {
                emit LogSkipOrder(oldOrderKey, newOrder.salt);
                return (LibOrder.ORDERKEY_SENTINEL, 0);
            }
        // 取消旧订单
        uint256 oldFilledAmount = filledAmount[oldOrderKey];
        _removeOrder(oldOrder);
        _cancelOrder(oldOrderKey);

        newOrderKey = _addOrder(newOrder);

        // 创建新订单
        if (oldOrder.side == LibOrder.Side.List) {
            EasySwapVault(_vault).editNFT(oldOrderKey, newOrderKey);
        } else if (oldOrder.side == LibOrder.Side.Bid) {
            uint256 oldRemainPrice = Price.unwrap(oldOrder.price) * (oldOrder.nft.amount - oldFilledAmount);
            uint256 newRemainPrice = Price.unwrap(newOrder.price) * (newOrder.nft.amount - oldFilledAmount);
            if (newRemainPrice > oldRemainPrice) {
                deltaBidPrice = newRemainPrice - oldRemainPrice;
                EasySwapVault(_vault).editETH{value: uint256(deltaBidPrice)}(
                    oldOrderKey,
                    newOrderKey,
                    oldRemainPrice,
                    newRemainPrice,
                    oldOrder.maker
                );
            } else {
                EasySwapVault(_vault).editETH(
                    oldOrderKey,
                    newOrderKey,
                    oldRemainPrice,
                    newRemainPrice,
                    oldOrder.maker
                );
            }
        }
    }

    function _matchOrder(
        LibOrder.Order calldata listOrder,
        LibOrder.Order calldata bidOrder,
        uint256 msgValue
    ) internal returns (uint128 costValue) {
        OrderKey listOrderKey = LibOrder.hash(listOrder);
        OrderKey bidOrderKey = LibOrder.hash(bidOrder);
        _isMatchAvailable(listOrder, bidOrder, listOrderKey, bidOrderKey);

        if (msg.sender == listOrder.maker) {
            // 卖家不用传eth
            require(msgValue == 0, "HD: msg.value > 0");
            // 检查订单是否在vault里
            bool isListExist = orders[listOrderKey].order.maker != address(0);

            uint128 listPrice = Price.unwrap(listOrder.price);
            if (isListExist) {
                _removeOrder(listOrder);
                _updateFilledAmount(listOrder.nft.amount, listOrderKey);
            }
            _updateFilledAmount(filledAmount[bidOrderKey] + 1, bidOrderKey);
            // 转账eth
            EasySwapVault(_vault).withdrawETH(
                bidOrderKey,
                listPrice,
                address(this)
            );

            uint128 protocolFee = _shareToAmount(listPrice, protocolShare);
            payable(listOrder.maker).safeTransferETH(listPrice - protocolFee);
            // 转移nft
            if (isListExist) {
                EasySwapVault(_vault).withdrawNFT(
                    listOrderKey,
                    bidOrder.maker,
                    listOrder.nft.collection,
                    listOrder.nft.tokenId
                );
            } else {
                EasySwapVault(_vault).transferERC721(
                    listOrder.maker,
                    bidOrder.maker,
                    listOrder.nft
                );
            }
        } else if (msg.sender == bidOrder.maker) {
            bool isBidExist = orders[bidOrderKey].order.maker != address(0);

            uint128 bidPrice = Price.unwrap(bidOrder.price);
            uint128 listPrice = Price.unwrap(listOrder.price);
            if (!isBidExist) {
                require(msgValue >= listPrice, "HD: value < fill price");
            } else {
                require(bidPrice >= listPrice, "HD: buy price < fill price");
                EasySwapVault(_vault).withdrawETH(
                    bidOrderKey,
                    bidPrice,
                    address(this)
                );
                _removeOrder(bidOrder);
                _updateFilledAmount(filledAmount[bidOrderKey] + 1, bidOrderKey);
            }
            _updateFilledAmount(bidOrder.nft.amount, bidOrderKey);
            // 转账ETH
            uint128 protocolFee = _shareToAmount(listPrice, protocolShare);
            payable(listOrder.maker).safeTransferETH(listPrice - protocolFee);
            if (bidPrice > listPrice) {
                payable(bidOrder.maker).safeTransferETH(bidPrice - listPrice);
            }
            // 转移nft
            EasySwapVault(_vault).withdrawNFT(
                listOrderKey,
                bidOrder.maker,
                bidOrder.nft.collection,
                bidOrder.nft.tokenId
            );
            costValue = isBidExist ? 0 : bidPrice;

        } else {
            revert("HD: sender invalid");
        }


    }

    function _isMatchAvailable(
        LibOrder.Order memory sellOrder,
        LibOrder.Order memory buyOrder,
        OrderKey sellOrderKey,
        OrderKey buyOrderKey
    ) internal view {
        require(
            OrderKey.unwrap(sellOrderKey) != OrderKey.unwrap(buyOrderKey),
            "HD: same order"
        );
        require(
            sellOrder.side == LibOrder.Side.List &&
                buyOrder.side == LibOrder.Side.Bid,
            "HD: side mismatch"
        );
        require(
            sellOrder.saleKind == LibOrder.SaleKind.FixedPriceForItem,
            "HD: kind mismatch"
        );
        require(sellOrder.maker != buyOrder.maker, "HD: same maker");
        require( // check if the asset is the same
            buyOrder.saleKind == LibOrder.SaleKind.FixedPriceForCollection ||
                (sellOrder.nft.collection == buyOrder.nft.collection &&
                    sellOrder.nft.tokenId == buyOrder.nft.tokenId),
            "HD: asset mismatch"
        );
        require(
            filledAmount[sellOrderKey] < sellOrder.nft.amount &&
                filledAmount[buyOrderKey] < buyOrder.nft.amount,
            "HD: order closed"
        );
    }

    function _shareToAmount(
        uint128 total,
        uint128 share
    ) internal pure returns (uint128) {
        return (total * share) / 10000;
    }

    // 创建订单
    function makeOrders(
        LibOrder.Order[] calldata newOrders
    ) external payable returns (OrderKey[] memory newOrderKeys) {
        uint256 orderAmount = newOrders.length;
        newOrderKeys = new OrderKey[](orderAmount);

        // 总eth数量
        uint128 ETHAmount;
        for (uint256 i = 0; i < orderAmount; ++i) {
            uint128 bidPrice;
            if (newOrders[i].side == LibOrder.Side.Bid) {
                bidPrice = Price.unwrap(newOrders[i].price) * newOrders[i].nft.amount;
            }
            OrderKey newOrderKey = _makeOrderTry(newOrders[i], bidPrice);
            newOrderKeys[i] = newOrderKey;
            if (
                OrderKey.unwrap(newOrderKey) != OrderKey.unwrap(LibOrder.ORDERKEY_SENTINEL)
            ) {
                ETHAmount += bidPrice;
            }
        }
        if (msg.value > ETHAmount) {
            // 退还多余的eth
            payable(msg.sender).safeTransferETH(msg.value - ETHAmount);
        }
    }

    function cancelOrders(
        OrderKey[] calldata orderKeys
    ) external returns (bool[] memory successes) {
        successes = new bool[](orderKeys.length);
        for (uint256 i = 0; i < orderKeys.length; ++i) {
            bool success = _cancelOrderTry(orderKeys[i]);
            successes[i] = success;
        }
    }

    function editOrders(
        LibOrder.EditDetail[] calldata editDetails
    ) external payable returns (OrderKey[] memory newOrderKeys) {
        newOrderKeys = new OrderKey[](editDetails.length);
        uint256 bidETHAmount;
        for (uint256 i = 0; i < editDetails.length; ++i) {
            (OrderKey newOrderKey, uint256 deltaPrice) = _editOrderTry(
                editDetails[i].oldOrderKey,
                editDetails[i].newOrder
            );
            bidETHAmount += deltaPrice;
            newOrderKeys[i] = newOrderKey;
        }
        if (msg.value > bidETHAmount) {
            // 退还多余的eth
            payable(msg.sender).safeTransferETH(msg.value - bidETHAmount);
        }
    }

    function matchOrder(
        LibOrder.Order calldata listOrder,
        LibOrder.Order calldata bidOrder
    ) external payable {
        uint256 costValue = _matchOrder(listOrder, bidOrder, msg.value);
        if (msg.value > costValue) {
            payable(msg.sender).safeTransferETH(msg.value - costValue);
        }
    }

    function matchOrderWithoutPayback(
        LibOrder.Order calldata sellOrder,
        LibOrder.Order calldata buyOrder,
        uint256 msgValue
    )
        external
        payable
        returns (uint128 costValue)
    {
        costValue = _matchOrder(sellOrder, buyOrder, msgValue);
    }

    function matchOrders(
        LibOrder.MatchDetail[] calldata matchDetails
    ) external payable returns (bool[] memory successes) {
        successes = new bool[](matchDetails.length);
        uint128 bidEHTAmount;

        for (uint256 i = 0; i < matchDetails.length; ++i) {
            LibOrder.MatchDetail calldata matchDetail = matchDetails[i];
            (bool success, bytes memory data) = address(this).delegatecall(
                abi.encodeWithSignature(
                    "matchOrderWithoutPayback((uint8,uint8,address,(uint256,address,uint96),uint128,uint64,uint64),(uint8,uint8,address,(uint256,address,uint96),uint128,uint64,uint64),uint256)",
                    matchDetail.sellOrder,
                    matchDetail.buyOrder,
                    msg.value - bidEHTAmount
                )
            );
            if (success) {
                successes[i] = success;
                if (matchDetail.buyOrder.maker == msg.sender) {
                    uint128 buyPrice;
                    buyPrice = abi.decode(data, (uint128));
                    bidEHTAmount += buyPrice;

                }
            } else {

            }
        }
        if (msg.value > bidEHTAmount) {
            payable(msg.sender).safeTransferETH(msg.value - bidEHTAmount);
        }
    }
    
}