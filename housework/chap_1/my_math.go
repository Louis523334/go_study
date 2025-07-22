package main

import "unicode"

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func isLetterNum(c rune) bool {
	return unicode.IsLetter(c) || unicode.IsDigit(c)
}
