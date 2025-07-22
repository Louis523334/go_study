package main

import (
	"fmt"
	"time"
)

func main() {
	// // 1.1测试
	// var num MyInt
	// for num < 10 {
	// 	num.increment()
	// }
	// fmt.Println(num)

	// // 1.2测试
	// var nums MySlice
	// nums = MySlice{1, 2, 3, 4, 5}
	// nums.double()
	// fmt.Println(nums)

	// 2.2
	for i := 1; i < 11; i++ {
		go printOdd(i)
		go printEven(i)
		time.Sleep(500 * time.Millisecond)
	}
}

// 1.1
type MyInt int

func (num *MyInt) increment() {
	*num++
}

// 1.2
type MySlice []int

func (nums *MySlice) double() {
	for idx := range *nums {
		(*nums)[idx] *= 2
	}
}

// 2.1
func printOdd(num int) {
	if num%2 != 0 {
		fmt.Println("我输出奇数: ", num)
	}
}

func printEven(num int) {
	if num%2 == 0 {
		fmt.Println("我输出偶数: ", num)
	}
}
