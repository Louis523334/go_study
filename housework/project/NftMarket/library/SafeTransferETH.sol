// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

library SafeTransferETH {
    function safeTransferETH(address payable to, uint256 amount) internal {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");

        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}