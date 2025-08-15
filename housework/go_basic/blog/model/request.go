package model

type CommentRequest struct {
	Content string `json:"content"`
	UserID  uint   `json:"user_id"`
	PostID  uint   `json:"post_id"`
}

type PostRequest struct {
	ID uint `json:"id"`
}
