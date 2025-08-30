// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyNFT is ERC721 {

    constructor() ERC721("MyNFT", "MFT") {}
    
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}