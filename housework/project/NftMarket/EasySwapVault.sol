// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {LibOrder, OrderKey} from "./library/LibOrder.sol";
import "./library/SafeTransferETH.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


contract EasySwapVault {
    using SafeTransferETH for address payable;
    
    address public owner;
    address public orderBook;
    mapping (OrderKey => uint256) public ETHBalance;
    mapping (OrderKey => uint256) public NFTBalance;

    modifier onlyOrderBook {
        require(msg.sender == orderBook, "Only orderbook can call");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    function setOrderBook(address _orderBook) public onlyOwner {
        require(_orderBook != address(0), "Only owner can set orderbook address");
        orderBook = _orderBook;
    }

    // 查询某个订单的eth价格和nft的id
    function balanceOf(OrderKey orderKey) external view returns (uint256 ETHAmount, uint256 tokenId) {
        ETHAmount = ETHBalance[orderKey];
        tokenId = NFTBalance[orderKey];
    }

    // 给某个订单存入eth
    function depositETH(OrderKey orderkey, uint256 amount) external payable onlyOrderBook {
        require(msg.value > amount, "HV: not match ETHAmount");
        ETHBalance[orderkey] += msg.value;
    }

    // 从某个订单去除eth
    function withdrawETH(OrderKey orderkey, uint256 amount, address to) external onlyOrderBook {
        require(ETHBalance[orderkey] >= amount, "Not enough ETH to withdraw");
        ETHBalance[orderkey] -= amount;
        payable(to).safeTransferETH(amount);
    }

    // 存入nft
    function depositNFT(
        OrderKey orderKey,
        address from,
        address collection,
        uint256 tokenId
    ) external onlyOrderBook {
        IERC721(collection).safeTransferFrom(from, address(this), tokenId);
        NFTBalance[orderKey] = tokenId;
    }

    // 取出nft
    function withdrawNFT(
        OrderKey orderKey,
        address to,
        address collection,
        uint256 tokenId
    ) external onlyOrderBook {
        require(NFTBalance[orderKey] == tokenId, "HV: not match tokenId");
        require(to != address(0), "Can not transfer token to address 0");
        delete NFTBalance[orderKey];
        IERC721(collection).safeTransferFrom(address(this), to, tokenId);
    }

    function editETH(
        OrderKey oldOrderKey,
        OrderKey newOrderKey,
        uint256 oldETHAmount,
        uint256 newETHAmount,
        address to
    ) external payable onlyOrderBook {
        require(ETHBalance[oldOrderKey] == oldETHAmount, "ETH amount not matching");
        ETHBalance[oldOrderKey] = 0;
        if (oldETHAmount > newETHAmount) {
            ETHBalance[newOrderKey] = newETHAmount;
            payable(to).safeTransferETH(oldETHAmount - newETHAmount);
        } else if (oldETHAmount < newETHAmount) {
            require(msg.value >= newETHAmount - oldETHAmount, "Amount not enough");
            ETHBalance[newOrderKey] = msg.value + oldETHAmount;
        } else {
            ETHBalance[newOrderKey] = oldETHAmount;
        }
    }

    function editNFT(
        OrderKey oldOrderKey,
        OrderKey newOrderKey
    ) external onlyOrderBook {
        NFTBalance[newOrderKey] = NFTBalance[oldOrderKey];
        delete NFTBalance[oldOrderKey];
    }

    function transferERC721(
        address from,
        address to,
        LibOrder.Asset calldata assets
    ) external onlyOrderBook {
        IERC721(assets.collection).safeTransferFrom(from, to, assets.tokenId);
    }

    function batchTransferERC721(
        address to,
        LibOrder.NFTInfo[] calldata assets
    ) external onlyOrderBook {
        for(uint256 i = 0; i < assets.length; i++) {
                IERC721(assets[i].collection).safeTransferFrom(
                msg.sender,
                to,
                assets[i].tokenId
            );
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}

    uint256[50] private __gap;
    
}