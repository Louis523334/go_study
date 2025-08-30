// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract Voting {
    // 一个mapping来存储候选人的得票数
    mapping(address addr => int num) private votes;
    address[] private candidates;
    mapping(address addr => bool) added;

    // 一个vote函数，允许用户投票给某个候选人
    function vote(address addr) public {
        if (!added[addr]) {
            candidates.push(addr);
            added[addr] = true;
        }
        votes[addr] += 1;
    }

    // 一个getVotes函数，返回某个候选人的得票数
    function getVotes(address addr) external view returns (int) {
        return votes[addr];
    }

    // 一个resetVotes函数，重置所有候选人的得票数
    function resetVotes() public {
        for (uint i = 0; i < candidates.length; i++) {
            votes[candidates[i]] = 0;
        }
    }
}