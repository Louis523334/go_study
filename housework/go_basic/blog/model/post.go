package model

import "gorm.io/gorm"

type Post struct {
	gorm.Model
	Title   string `gorm:"not null" json:"title" binding:"required"`
	Content string `gorm:"not null" json:"content" binding:"required"`
	UserID  uint
	User    User
}
