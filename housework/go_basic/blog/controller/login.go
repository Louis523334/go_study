package controller

import (
	"fmt"
	"net/http"

	"github.com/Louis523334/blog/model"
	"github.com/Louis523334/blog/service"
	"github.com/gin-gonic/gin"
)

func RegisterController(c *gin.Context) {
	var user model.User
	if err := c.ShouldBindJSON(&user); err != nil {
		panic(err)
	}
	fmt.Println(user)
	// 逻辑
	err := service.RegisterService(&user)
	if err == nil {
		model.Success(c, "注册成功")
	} else {
		panic(err)
	}

}

func LoginController(c *gin.Context) {
	var user model.User
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	}
	// 逻辑
	token, err := service.LoginService(&user)
	if err == nil {
		model.Success(c, map[string]string{"token": token})
	} else {
		panic(err)
	}

}
