package model

import "gorm.io/gorm"

type Comment struct {
	gorm.Model
	Content string `gorm:"not null" binding:"required"`
	UserID  uint
	User    User
	PostID  uint
	Post    Post
}
