package main

import (
	"sort"
	"unicode"
	"unicode/utf8"
)

func main() {
	// 测试1
	// list_num := [9]int32{1, 2, 3, 4, 3, 2, 1, 4, -3}
	// res := singleNum(list_num[:])
	// fmt.Println(res)

	// 测试2
	// s := "a"
	// res := isPalindromicNumber(s)
	// fmt.Println(res)

	// 3.测试
	// var aaa string
	// aaa = "()[][]"
	// res := isValidString(aaa)
	// fmt.Println(res)

	// 4.测试
	// a1 := []string{"aaa"}
	// res := findLongestCommonPrefix(a1)
	// fmt.Println(res)

	// 5.测试
	// digits := []int{0, 2, 3}
	// res := plusOne(digits)
	// fmt.Println(res)

	// 6.测试
	// sorted_arr := []int{1, 1, 2, 3, 3, 4, 5, 5, 6}
	// res := removeDuplicates(sorted_arr)
	// fmt.Println(res)
}

// 1.找出只出现一次元素
func singleNum(nums []int) int {
	var res int
	// 位运算会将重复的元素至0, 0与a相与为a
	for _, val := range nums {
		res = res ^ val
	}
	return res
}

// 2.判断是否为回文数
func isPalindromicNumber(s string) bool {
	left, right := 0, len(s)-1
	// 根据索引比较数是否相同, 有不同的则返回false
	for left < right {
		for left < right && !isLetterNum(rune(s[left])) {
			left++
		}
		for left < right && !isLetterNum(rune(s[right])) {
			right--
		}
		if unicode.ToLower(rune(s[left])) != unicode.ToLower(rune(s[right])) {
			return false
		}

		left++
		right--
	}
	return true
}

// 3.判断字符串是否有效
func isValidString(s string) bool {
	var stack Stack
	for _, c := range s {
		if c == '(' || c == '{' || c == '[' {
			stack.push(c)
		}
		if c == ')' || c == '}' || c == ']' {
			if stack.isEmpty() {
				return false
			}
			if (c == ')' && stack.peek() == '(') ||
				(c == '}' && stack.peek() == '{') ||
				(c == ']' && stack.peek() == '[') {
				stack.pop()
			} else {
				return false
			}
		}
	}
	return stack.isEmpty()
}

// 4.寻找字符串最长公共前缀
func findLongestCommonPrefix(strs []string) string {
	if len(strs) == 0 {
		return ""
	}
	if len(strs) == 1 {
		return strs[0]
	}
	prefix := strs[0]
	for i := 1; i < len(strs); i++ {
		val := strs[i]
		if utf8.RuneCountInString(prefix) >= utf8.RuneCountInString(val) {
			prefix = prefix[:utf8.RuneCountInString(val)]
		}

		for j := 0; j < utf8.RuneCountInString(prefix); j++ {
			if prefix[j] != val[j] {
				prefix = prefix[:j]
				break
			}
		}
	}
	return prefix
}

// 5.数组数据加1
func plusOne(digits []int) []int {
	for i := len(digits) - 1; i >= 0; i-- {
		digits[i]++
		if digits[i] == 10 {
			digits[i] = 0
		} else {
			return digits
		}
		if i == 0 && digits[i] == 0 {
			digits = append([]int{1}, digits...)
		}
	}
	return digits

}

// 6.删除有序数组重复项
func removeDuplicates(nums []int) int {
	if len(nums) == 0 {
		return 0
	}
	if len(nums) == 1 {
		return 1
	}
	slow := 0
	for i := 1; i < len(nums); i++ {
		if nums[i-1] != nums[i] {
			slow++
			nums[slow] = nums[i]
		}
	}
	return len(nums[:slow+1])
}

// 7.合并区间
func mergeIntervals(intervals [][]int) [][]int {
	if len(intervals) == 0 {
		return nil
	}
	// 排序数组
	sort.Slice(intervals, func(i, j int) bool {
		return intervals[i][0] < intervals[j][0]
	})
	merged := [][]int{intervals[0]}
	for i := 1; i < len(intervals); i++ {
		last := merged[len(merged)-1]
		curr := intervals[i]
		if curr[0] <= last[1] {
			last[1] = max(last[1], curr[1])
		} else {
			merged = append(merged, curr)
		}
	}
	return merged
}

// 8.找出两数之和
func twoSum(nums []int, target int) []int {
	hashMap := make(map[int]int)
	for idx, val := range nums {
		_, ok := hashMap[target-val]
		if ok {
			return []int{idx, hashMap[target-val]}
		}
		hashMap[val] = idx
	}
	return []int{}
}
