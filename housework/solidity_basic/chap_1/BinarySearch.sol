// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract BinarySearch {

    function search(int[] memory arr, int target) public pure returns (int) {
        uint left = 0;
        uint right = arr.length - 1;

        while (left <= right) {
            uint mid = (left + right) / 2;
            if (arr[mid] < target) {
                left = mid + 1;
            } else if (arr[mid] > target) {
                right = mid - 1;
            } else if (arr[mid] == target) {
                return int(mid);
            }

        }


        return -1;
    }

}