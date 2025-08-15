package service

import (
	"time"

	databse "github.com/Louis523334/blog/database"
	"github.com/Louis523334/blog/errs"
	"github.com/Louis523334/blog/model"
	"github.com/golang-jwt/jwt"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func RegisterService(user *model.User) error {
	// 检查用户是否存在
	err := databse.DB.Where("username = ?", user.Username).First(&model.User{}).Error
	if err == gorm.ErrRecordNotFound {
		// 用户不存在, 添加用户信息
		// 1.加密密码
		bytes, _ := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
		user.Password = string(bytes)
		// 2.新增数据
		databse.DB.Create(&user)
	} else {
		return errs.ErrUserExist
	}
	return nil
}

func LoginService(user *model.User) (string, error) {
	var userQuery model.User
	err := databse.DB.Where("username = ?", user.Username).First(&userQuery).Error
	if err == gorm.ErrRecordNotFound {
		return "", errs.ErrUserNotFound
	} else {
		err := bcrypt.CompareHashAndPassword([]byte(userQuery.Password), []byte(user.Password))
		if err != nil {
			return "", errs.ErrWrongPass
		}
	}
	// 生成JWT令牌
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"id":       userQuery.ID,
		"username": userQuery.Username,
		"exp":      time.Now().Add(time.Hour * 8).Unix(),
	})
	tokenString, err := token.SignedString([]byte("Killer_queen"))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}
