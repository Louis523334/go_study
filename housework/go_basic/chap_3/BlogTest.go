package chap_3

import (
	"fmt"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// 用户User
type User struct {
	gorm.Model
	Name    string
	PostNum uint
	Posts   []Post
}

// 文章Post
type Post struct {
	gorm.Model
	Content   string
	IsComment string
	Comments  []Comment
	UserID    uint
}

// 评论Comment
type Comment struct {
	gorm.Model
	Content string
	PostID  uint
}

func BlogTest() {
	dsn := "root:123456@tcp(127.0.0.1:3306)/gorm_test?charset=utf8mb4&parseTime=True&loc=Local"
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		fmt.Println(err)
		fmt.Println("Failed to connect")
	} else {
		fmt.Println("Mysql Connected")
	}
	// 创建表
	// db.AutoMigrate(&User{})
	// db.AutoMigrate(&Post{})
	// db.AutoMigrate(&Comment{})

	// 插入user数据
	// users := []User{
	// 	{Name: "张三"},
	// 	{Name: "李四"},
	// }
	// db.Create(users)
	// 插入post数据
	// post := Post{Content: "吃饭了吗", UserID: 1}
	// post := Post{Content: "我今天还没吃饭", UserID: 1}
	// db.Create(&post)
	// 插入comment数据
	// comment := Comment{Content: "111", PostID: 1}
	// db.Create(&comment)
	// // 删除comment数据
	// db.Unscoped().Delete(&comment)

	// 使用Gorm查询某个用户发布的所有文章及其对应的评论信息
	var user User
	db.Model(&User{}).Where("id = ?", 1).Find(&user)
	var posts []Post
	db.Model(&Post{}).Where("user_id = ?", user.ID).Preload("Comments").Find(&posts)
	// fmt.Println(posts)
	// 使用Gorm查询评论数量最多的文章信息
	var post Post
	db.Raw(`
		with t1 as (
		select post_id,
			count(*) num
		from comments
		group by post_id
		order by num desc
		limit 1
		)
		select *
		from posts
		where id = (select post_id from t1)
	`).Scan(&post)
	fmt.Println(post)
}

// 在文章创建时自动更新用户的文章数量统计字段
func (p *Post) AfterCreate(tx *gorm.DB) error {
	err1 := tx.Model(&User{}).Where("id = ?", p.UserID).UpdateColumn("post_num", gorm.Expr("post_num + ?", 1)).Error
	return err1
}

// 在评论删除时检查文章的评论数量，如果评论数量为 0，则更新文章的评论状态为 "无评论"
func (c *Comment) AfterDelete(tx *gorm.DB) error {
	fmt.Println("我只想了")
	fmt.Println(c.PostID)
	var count int64
	tx.Model(&Comment{}).Where("post_id = ?", c.PostID).Count(&count)
	// fmt.Println(count)
	fmt.Println(c.PostID)
	if count == 0 {
		err := tx.Model(&Post{}).Where("id = ?", c.PostID).Update("is_comment", "无评论").Error
		if err != nil {
			return err
		}
	}
	return nil
}
