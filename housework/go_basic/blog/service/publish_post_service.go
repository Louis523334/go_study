package service

import (
	"errors"

	databse "github.com/Louis523334/blog/database"
	"github.com/Louis523334/blog/model"
)

func PostService(post *model.Post) error {
	err := databse.DB.Create(post).Error

	return err

}

func GetService() (*[]model.PostResponse, error) {
	var posts []model.PostResponse
	err := databse.DB.Raw("select * from posts").Scan(&posts).Error

	return &posts, err
}

func GetByTitleService(title string) (*model.PostResponse, error) {
	var post model.PostResponse
	var err error
	res := databse.DB.Raw("select * from posts where title = ?", title).Scan(&post)
	if res.RowsAffected == 0 {
		err = errors.New("文章不存在")
	}

	return &post, err
}

func SetService(post *model.Post, userID uint) error {
	var postNew model.Post
	res := databse.DB.Raw("select * from posts where id = ?", post.ID).Scan(&postNew)
	if res.RowsAffected == 0 {
		panic(errors.New("文章不存在"))
	}
	if res.Error != nil {
		panic(res.Error)
	}
	if userID != postNew.UserID {
		panic(errors.New("只能修改自己的文章"))
	}
	err := databse.DB.Exec(`update posts SET content = ? where id = ?`, post.Content, post.ID).Error

	return err

}

func DeleteService(id uint, userID uint) error {
	var postNew model.Post
	res := databse.DB.Raw("select * from posts where id = ?", id).Scan(&postNew)
	if res.RowsAffected == 0 {
		panic(errors.New("文章不存在"))
	}
	if res.Error != nil {
		panic(res.Error)
	}
	if userID != postNew.UserID {
		panic(errors.New("只能删除自己的文章"))
	}
	var err error
	tx := databse.DB.Begin() // 开启事务
	if err = databse.DB.Exec(`delete from posts where id = ?`, id).Error; err != nil {
		tx.Rollback()
		return err
	}
	if err = databse.DB.Exec(`delete from comments where post_id = ?`, id).Error; err != nil {
		tx.Rollback()
		return err
	}
	tx.Commit()
	if res.RowsAffected == 0 {
		err = res.Error
	}

	return err
}
