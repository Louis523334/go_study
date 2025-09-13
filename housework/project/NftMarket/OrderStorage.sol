// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import {RedBlackTreeLibrary, Price} from "./library/RedBlackTreeLibrary.sol";
import {LibOrder, OrderKey} from "./library/LibOrder.sol";

contract OrderStorage {
    using RedBlackTreeLibrary for RedBlackTreeLibrary.Tree;

    // 存放所有订单
    mapping (OrderKey => LibOrder.DBOrder) public orders;
    // 价格树
    mapping (address => mapping (LibOrder.Side => RedBlackTreeLibrary.Tree)) public priceTrees;
    // 每个价格的订单
    mapping (address => mapping (LibOrder.Side => mapping (Price => LibOrder.OrderQueue))) public orderQueues;

    function plusOne(uint256 x) public pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    function getBestPrice(address collection, LibOrder.Side side) public view returns (Price) {
        Price price = (side == LibOrder.Side.Bid) ? priceTrees[collection][side].last() : priceTrees[collection][side].first();
        return price;
    }

    function getNextBestPrice(address collection, LibOrder.Side side, Price price) public view returns (Price) {
        Price nextBestPrice;
        if (RedBlackTreeLibrary.isEmpty(price)) {
            nextBestPrice = (side == LibOrder.Side.Bid) ? priceTrees[collection][side].last() : priceTrees[collection][side].first();
        } else {
            nextBestPrice = (side == LibOrder.Side.Bid) ? priceTrees[collection][side].prev(price) : priceTrees[collection][side].next(price);
        }
        return nextBestPrice;
    }

    function _addOrder(LibOrder.Order memory order) internal returns (OrderKey) {
        // 获取订单hash值
        OrderKey orderKey = LibOrder.hash(order);
        // 获取价格树
        RedBlackTreeLibrary.Tree storage priceTree = priceTrees[order.nft.collection][order.side];
        // 如果价格树中不存在价格则插入, 存在则添加订单
        if (!priceTree.exists(order.price)) {
            priceTree.insert(order.price);
        }
        // 获取订单链表
        LibOrder.OrderQueue storage orderQueue = orderQueues[order.nft.collection][order.side][order.price];
        // 检查链表是否存在, 不存在则初始化
        if (LibOrder.isSentinel(orderQueue.head)) {
            orderQueue.head = orderKey;
            orderQueue.tail = orderKey;
            orders[orderKey] = LibOrder.DBOrder(order, LibOrder.ORDERKEY_SENTINEL);
        } else {
            orders[orderQueue.tail].next = orderKey;
            orders[orderKey] = LibOrder.DBOrder(order, LibOrder.ORDERKEY_SENTINEL);
            orderQueue.tail = orderKey;
        }
        return orderKey;
    }

    function _removeOrder(LibOrder.Order memory order) internal returns (OrderKey) {
        // 获取订单hash值
        OrderKey orderKey;
        LibOrder.OrderQueue storage orderQueue = orderQueues[order.nft.collection][order.side][order.price];
        orderKey = orderQueue.head;
        OrderKey preOrderKey;
        bool found;
        while (LibOrder.isNotSentinel(orderKey) && !found) {
            LibOrder.DBOrder memory dbOrder = orders[orderKey];
            if (
                (dbOrder.order.maker == order.maker) &&
                (dbOrder.order.saleKind == order.saleKind) &&
                (dbOrder.order.expiry == order.expiry) &&
                (dbOrder.order.salt == order.salt) &&
                (dbOrder.order.nft.tokenId == order.nft.tokenId) &&
                (dbOrder.order.nft.amount == order.nft.amount)
            ) {
                OrderKey temp = orderKey;
                if (OrderKey.unwrap(orderQueue.head) == OrderKey.unwrap(orderKey)) {
                    orderQueue.head = dbOrder.next;
                } else {
                    orders[preOrderKey].next = dbOrder.next;
                }
                if (OrderKey.unwrap(orderQueue.tail) == OrderKey.unwrap(orderKey)) {
                    orderQueue.tail = preOrderKey;
                }
                preOrderKey = orderKey;
                orderKey = dbOrder.next;
                delete orders[temp];
                found = true;
            } else {
                preOrderKey = orderKey;
                orderKey = dbOrder.next;
            }
        }
        if (found) {
            if (LibOrder.isSentinel(orderQueue.head)) {
                delete orderQueues[order.nft.collection][order.side][order.price];
                RedBlackTreeLibrary.Tree storage priceTree = priceTrees[order.nft.collection][order.side];
                if (priceTree.exists(order.price)) {
                    priceTree.remove(order.price);
                }
        }

    } else {
        revert("Cannot remove missing order");
    }
    return orderKey;
}

    function getOrders(
        address collection,
        uint256 tokenId,
        LibOrder.Side side,
        LibOrder.SaleKind saleKind,
        uint256 count,
        Price price,
        OrderKey firstOrderKey
    ) external view returns (LibOrder.Order[] memory resultOrders, OrderKey nextOrderKey) {
        resultOrders = new LibOrder.Order[](count);

        if (RedBlackTreeLibrary.isEmpty(price)) {
            price = getBestPrice(collection, side);
        } else {
            if (LibOrder.isSentinel(firstOrderKey)) {
                price = getNextBestPrice(collection, side, price);
            }
        }

        uint256 i;
        while (RedBlackTreeLibrary.isNotEmpty(price) && i < count) {
            LibOrder.OrderQueue memory orderQueue = orderQueues[collection][side][price];
            OrderKey orderKey = orderQueue.head;
            if (LibOrder.isNotSentinel(firstOrderKey)) {
                while (
                    LibOrder.isNotSentinel(orderKey) && OrderKey.unwrap(orderKey) != OrderKey.unwrap(firstOrderKey)
                ) {
                    LibOrder.DBOrder memory order = orders[orderKey];
                    orderKey = order.next;
                }
                firstOrderKey = LibOrder.ORDERKEY_SENTINEL;
            }

            while (LibOrder.isNotSentinel(orderKey) && i < count) {
                LibOrder.DBOrder memory dbOrder = orders[orderKey];
                orderKey = dbOrder.next;
                if (
                    (dbOrder.order.expiry == 0 ||
                    dbOrder.order.expiry >= block.timestamp) &&
                    side == dbOrder.order.side &&
                    saleKind == dbOrder.order.saleKind &&
                    tokenId == dbOrder.order.nft.tokenId
                ) {
                    resultOrders[i] = dbOrder.order;
                    nextOrderKey = dbOrder.next;
                    i = plusOne(i);
                }
                price = getNextBestPrice(collection, side, price);
            }
        }
    }

    function getBestOrder(
        address collection,
        uint256 tokenId,
        LibOrder.Side side,
        LibOrder.SaleKind saleKind
    ) external view returns (LibOrder.Order memory orderResult) {
        Price price = getBestPrice(collection, side);
        while (RedBlackTreeLibrary.isNotEmpty(price)) {
            LibOrder.OrderQueue memory orderQueue = orderQueues[collection][side][price];
            OrderKey orderKey = orderQueue.head;
            while (LibOrder.isNotSentinel(orderKey)) {
                LibOrder.DBOrder memory dbOrder = orders[orderKey];
                if (
                    (dbOrder.order.expiry == 0 ||
                    dbOrder.order.expiry >= block.timestamp) &&
                    side == dbOrder.order.side &&
                    saleKind == dbOrder.order.saleKind &&
                    tokenId == dbOrder.order.nft.tokenId
                ) {
                    orderResult = dbOrder.order;
                }
                if (Price.unwrap(orderResult.price) > 0) {
                    break;
            }
            }
            price = getNextBestPrice(collection, side, price);
        }

    }

}