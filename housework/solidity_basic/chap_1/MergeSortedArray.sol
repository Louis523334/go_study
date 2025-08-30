// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract MergeSortedArray {

    function sort(uint[] memory nums1, uint num1, uint[] memory nums2) public pure returns (uint[] memory) {
        uint i = num1;
        uint j = nums2.length;
        uint k = nums1.length;

        while (i > 0 && j > 0) {
            if (nums1[i - 1] >= nums2[j - 1]) {
                nums1[k - 1] = nums1[i - 1];
                i--;
            } else {
                nums1[k - 1] = nums2[j - 1];
                j--;
            }
            k--;
        }

        while (j > 0) {
            nums1[k - 1] = nums2[j - 1];
            j--;
            k--;
        }

        return nums1;
    }
}