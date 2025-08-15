package controller

import (
	"github.com/Louis523334/blog/model"
	"github.com/Louis523334/blog/service"
	"github.com/gin-gonic/gin"
)

// 发布评论
func PostCommController(c *gin.Context) {
	var comment model.CommentRequest
	if err := c.ShouldBindJSON(&comment); err != nil {
		panic(err)
	}
	err := service.PostCommService(&comment)
	if err != nil {
		panic(err)
	}
	model.Success(c, "评论发布成功")
}

// 获取评论列表
func GetCommByPostIDController(c *gin.Context) {
	var post model.PostRequest
	if err := c.ShouldBindJSON(&post); err != nil {
		panic(err)
	}
	postId := post.ID
	comments, err := service.GetCommByPostIDService(postId)
	if err != nil {
		panic(err)
	}
	model.Success(c, *comments)
}
