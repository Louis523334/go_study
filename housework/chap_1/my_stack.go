package main

// import "fmt"

type Stack []rune

// 入栈
func (s *Stack) push(v rune) {
	*s = append(*s, v)
}

// 出栈
func (s *Stack) pop() (rune, bool) {
	if len(*s) == 0 {
		return 0, false
	}
	idx := len(*s) - 1
	v := (*s)[idx]
	*s = (*s)[:idx]
	return v, true
}

// 查看栈顶元素
func (s *Stack) peek() rune {
	if len(*s) == 0 {
		return 0
	}
	return (*s)[len(*s)-1]
}

// 判断栈是否为空
func (s *Stack) isEmpty() bool {
	return len(*s) == 0
}
