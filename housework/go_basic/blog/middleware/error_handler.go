package middleware

import (
	"errors"
	"fmt"
	"net/http"

	"github.com/Louis523334/blog/errs"
	"github.com/gin-gonic/gin"
)

func ErrorHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if r := recover(); r != nil {
				var apiErr *errs.APIError
				// 如果是我们定义的 APIError
				fmt.Println(r.(error))
				if errors.As(r.(error), &apiErr) {
					c.JSON(apiErr.Code, gin.H{
						"code":    apiErr.Code,
						"message": apiErr.Message,
					})
				} else {
					// 不是我们定义的，默认 500
					c.JSON(http.StatusInternalServerError, gin.H{
						"code":    500,
						"message": "服务器内部错误",
					})
				}
				c.Abort()
			}
		}()
		c.Next()
	}
}
