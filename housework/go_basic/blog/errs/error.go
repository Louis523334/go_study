package errs

import "net/http"

type APIError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// 定义公共错误
var (
	ErrBadRequest         = NewAPIError(http.StatusBadRequest, "请求参数错误")
	ErrUnauthorized       = NewAPIError(http.StatusUnauthorized, "未授权")
	ErrUserExist          = NewAPIError(http.StatusConflict, "用户已存在")
	ErrUserNotFound       = NewAPIError(http.StatusNotFound, "用户不存在")
	ErrInternalServer     = NewAPIError(http.StatusInternalServerError, "服务器内部错误")
	ErrDatabaseConnection = NewAPIError(http.StatusInternalServerError, "数据库连接错误")
	ErrWrongPass          = NewAPIError(http.StatusUnauthorized, "密码错误")
)

func NewAPIError(code int, msg string) *APIError {
	return &APIError{Code: code, Message: msg}
}

func (e *APIError) Error() string {
	return e.Message
}
