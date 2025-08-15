package service

import (
	databse "github.com/Louis523334/blog/database"
	"github.com/Louis523334/blog/model"
)

func PostCommService(commentRequest *model.CommentRequest) error {
	var comment model.Comment
	comment.Content = commentRequest.Content
	comment.UserID = commentRequest.UserID
	comment.PostID = commentRequest.PostID
	err := databse.DB.Create(&comment).Error
	return err
}

func GetCommByPostIDService(id uint) (*[]model.CommentResponse, error) {
	var comments []model.CommentResponse
	err := databse.DB.Raw("select * from comments where post_id = ?", id).Scan(&comments).Error

	return &comments, err
}
