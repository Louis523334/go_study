package main

import "fmt"

func main() {
	// 测试1
	// list_num := [9]int32{1, 2, 3, 4, 3, 2, 1, 4, -3}
	// res := single_num(list_num[:])
	// fmt.Println(res)

	// 测试2
	s := "a"
	res := is_palindromic_number(s)
	fmt.Println(res)
}

// 1.找出只出现一次元素
func single_num(list_num []int32) int32 {
	var res int32
	// 位运算会将重复的元素至0, 0与a相与为a
	for _, val := range list_num {
		res = res ^ val
	}
	return res
}

// 2.判断是否为回文数
func is_palindromic_number(s string) bool {
	len_s := len(s)
	// 根据索引比较数是否相同, 有不同的则返回false
	for i := 0; i < len_s/2; i++ {
		idx_back := len_s - i - 1
		if s[i] != s[idx_back] {
			return false
		}
	}
	return true
}

// 3.有效的括号
// func valid_parentheses(s string) bool {
// 	left_parentheses := [3]string{"(", "[", "{"}
// 	right_parentheses := [3]string{")", "]", "}"}
// 	for _, val := range s {

// 	}
// }
