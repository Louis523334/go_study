package controller

import (
	"errors"

	"github.com/Louis523334/blog/model"
	"github.com/Louis523334/blog/service"
	"github.com/gin-gonic/gin"
)

// 发布文章
func PostController(c *gin.Context) {
	var post model.Post
	if err := c.ShouldBindJSON(&post); err != nil {
		panic(err)
	}
	// if strings.TrimSpace(post.Title) == "" || strings.TrimSpace(post.Content) == "" {
	// 	panic(errors.New("文章标题和内容不能为空"))
	// }
	err := service.PostService(&post)
	if err != nil {
		panic(err)
	}
	model.Success(c, "文章发布成功")
}

// 获取全部文章
func GetController(c *gin.Context) {
	posts, err := service.GetService()
	if err != nil {
		panic(err)
	}
	model.Success(c, *posts)
}

// 根据标题获取文章
func GetByTitleController(c *gin.Context) {
	title := c.Param("title")
	post, err := service.GetByTitleService(title)
	if err != nil {
		panic(err)
	}
	model.Success(c, *post)
}

// 更新文章
func SetController(c *gin.Context) {
	var post model.Post
	if err := c.ShouldBindJSON(&post); err != nil {
		panic(err)
	}
	userIDAny, _ := c.Get("userID")
	userIDFloat, ok := userIDAny.(float64)
	if !ok {
		panic(errors.New("用户认证失败"))
	}
	userID := uint(userIDFloat)
	err := service.SetService(&post, userID)
	if err != nil {
		panic(err)
	}
	model.Success(c, "文章更新成功")
}

// 删除文章
func DeleteController(c *gin.Context) {
	var post model.Post
	if err := c.ShouldBindJSON(&post); err != nil {
		panic(err)
	}
	userIDAny, _ := c.Get("userID")
	userIDFloat, ok := userIDAny.(float64)
	if !ok {
		panic(errors.New("用户认证失败"))
	}
	userID := uint(userIDFloat)
	id := post.ID
	err := service.DeleteService(id, userID)
	if err != nil {
		panic(err)
	}
	model.Success(c, "文章删除成功")
}
