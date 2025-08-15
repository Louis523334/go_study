package middleware

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt"
)

var SecretKey = []byte("Killer_queen") // 和签发 token 时保持一致

func JWTAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 提取header
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Authorization header missing or invalid"})
			return
		}
		// 取出 token
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		// 解析 token
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			// 确保是 HMAC 签名方式
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return SecretKey, nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		// 解析 claims
		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			// 过期检测
			if exp, ok := claims["exp"].(float64); ok {
				if time.Now().Unix() > int64(exp) {
					c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Token expired"})
					return
				}
			}

			// 设置用户信息到上下文，后续处理函数中可以用 c.Get()
			c.Set("userID", claims["id"])
			c.Set("username", claims["username"])

			// 继续处理
			c.Next()
		} else {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
		}

	}
}
