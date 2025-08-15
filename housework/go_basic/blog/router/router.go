package router

import (
	controller "github.com/Louis523334/blog/controller"
	"github.com/Louis523334/blog/middleware"
	"github.com/gin-gonic/gin"
)

func SetupRouter() *gin.Engine {
	r := gin.Default()
	// 中间件
	r.Use(middleware.ErrorHandler())

	r.POST("/register", controller.RegisterController)
	r.POST("/login", controller.LoginController)
	auth := r.Group("")
	auth.Use(middleware.JWTAuthMiddleware())
	{
		// 帖子相关
		post := auth.Group("/post")
		{
			post.POST("/add", controller.PostController)
			post.GET("/get", controller.GetController)
			post.GET("/get/:title", controller.GetByTitleController)
			post.PUT("/put", controller.SetController)
			post.DELETE("/delete", controller.DeleteController)
		}

		// 评论相关
		comment := auth.Group("/comment")
		{
			comment.POST("/add", controller.PostCommController)
			comment.GET("/get", controller.GetCommByPostIDController)
		}
	}

	return r
}
