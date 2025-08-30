// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract Reverse {
    // 反转一个字符串。输入 "abcde"，输出 "edcba"
    function reverse (string memory s) public pure returns (string memory) {
        bytes memory sBytes = bytes(s);
        uint len = sBytes.length;
        bytes memory res = new bytes(len);
        for (uint i = 0; i < len; i++) {
            res[i] = sBytes[len - i - 1];
        }
        return string(res);
    }
}