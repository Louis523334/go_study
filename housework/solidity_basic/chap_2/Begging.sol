// SPDX-License-Identifier: MIT
pragma solidity ^0.8;


contract BeggingContract {
    mapping(address donater => uint256 value) private _donate;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function donate() external payable {
        require(msg.value > 0, "Donation must be greater than 0");
        _donate[msg.sender] += msg.value;
    }

    function getDonation(address donate) public view returns (uint256) {
        return _donate[donate];
    }

    function withdraw() external {
        require(msg.sender == owner, "Only owner can withdraw");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner).transfer(balance);
    }
}