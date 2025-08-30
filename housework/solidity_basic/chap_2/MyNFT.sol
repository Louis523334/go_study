// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";


contract MyNFT {
    using Strings for uint256;

    string private _name;
    string private _symbol;

    mapping (uint256 tokenId => address) private _owners;
    mapping (address => uint256) private _balances;

    constructor() {
        _name = "KING";
        _symbol = "KIN";
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function mint(address to, uint256 tokenId) public {
        // mint a NFT
        _owners[tokenId] = to;
        _balances[to] += 1;
    }

    function tokenURI(uint256 tokenId) public pure returns (string memory) {
        string memory baseUrl = _baseURI();
        // return bytes(baseUrl).length > 0 ? string.concat(baseUrl, tokenId.toString()) : "";
        return  baseUrl;

    }

    function _baseURI() private pure  returns (string memory) {
        return "https://pink-key-bobolink-15.mypinata.cloud/ipfs/bafkreihsbfxaj4kevhwvxlw7u7e3sfxi56nfwiymcnkycuwpju76jdrclm";
    }

    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        return _owners[tokenId];
    }
}