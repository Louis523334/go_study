// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./interface/IPledgeOracle.sol";

// 自定义的价格预言机

contract PledgeOracle is IPledgeOracle {

    address owner;
    mapping ( address => uint256) public tokenPrice;

    constructor (address _owner){
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only minter can mint");
        _;
    }


    function setPrice(address _token, uint256 _price) public onlyOwner {
        tokenPrice[_token] = _price;

    }

    function getPrice(address _token) external view returns (uint256) {
        return tokenPrice[_token];
    }

    function getPrices(uint256[] calldata assets) external view returns (uint256[2] memory) {
        address addressToken0 = address(uint160(assets[0]));
        address addressToken1 = address(uint160(assets[1]));

        return [tokenPrice[addressToken0], tokenPrice[addressToken1]];
    }

    function getUnderlyingPrice(uint256 cToken) external view returns (uint256) {
            address addressToken0 = address(uint160(cToken));
            return tokenPrice[addressToken0];
    }

    
}