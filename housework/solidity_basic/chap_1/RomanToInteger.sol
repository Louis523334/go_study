// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract RomanToInteger {
    mapping(string symbol => uint num) private romanMap;

    constructor() {
        romanMap["I"] = 1;
        romanMap["V"] = 5;
        romanMap["X"] = 10;
        romanMap["L"] = 50;
        romanMap["C"] = 100;
        romanMap["D"] = 500;
        romanMap["M"] = 1000;
        romanMap["IV"] = 4;
        romanMap["IX"] = 9;
        romanMap["XL"] = 40;
        romanMap["XC"] = 90;
        romanMap["CD"] = 400;
        romanMap["CM"] = 900;
    }

    function romanToInteger (string memory s) public view returns (uint) {
        bytes memory sBytes = bytes(s);
        uint len = sBytes.length;
        if (len == 1) {
            return romanMap[string(sBytes)];
        }
        for (uint i = 0; i < len; i++) {
            if (i + 1 != len && romanMap[string(sBytes[i:i+2])] != 0) {

            }
        }

    }
}