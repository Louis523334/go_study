// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract IntegerToRoman {

    struct IntegerSymbol {
        uint val;
        string symbol;
    }

    IntegerSymbol[] private integerSymbol;

    constructor() {
        integerSymbol.push(IntegerSymbol(1000, "M"));
        integerSymbol.push(IntegerSymbol(900, "CM"));
        integerSymbol.push(IntegerSymbol(500, "D"));
        integerSymbol.push(IntegerSymbol(400, "CD"));
        integerSymbol.push(IntegerSymbol(100, "C"));
        integerSymbol.push(IntegerSymbol(90, "XC"));
        integerSymbol.push(IntegerSymbol(50, "L"));
        integerSymbol.push(IntegerSymbol(40, "XL"));
        integerSymbol.push(IntegerSymbol(10, "X"));
        integerSymbol.push(IntegerSymbol(9, "IX"));
        integerSymbol.push(IntegerSymbol(5, "V"));
        integerSymbol.push(IntegerSymbol(4, "IV"));
        integerSymbol.push(IntegerSymbol(1, "I"));
    }

    function integerToRoman(uint num) public view returns (string memory) {
        string memory res;
        for (uint i = 0; i < integerSymbol.length; i++) {
            while (num >= integerSymbol[i].val) {
                num -= integerSymbol[i].val;
                res = string.concat(res, integerSymbol[i].symbol);
            }
            if (num == 0) {
                break;
            }
        }
        return res;
    }
}