package chap_3

import (
	"fmt"
	"log"

	_ "github.com/go-sql-driver/mysql" // 或 postgres/sqlite 等驱动
	"github.com/jmoiron/sqlx"
)

type Book struct {
	ID     uint    `db:"id"`
	Title  string  `db:"title"`
	Author string  `db:"author"`
	Price  float64 `db:"price"`
}

func BookTest() {
	db, err := sqlx.Connect("mysql", "root:123456@tcp(127.0.0.1:3306)/gorm_test")
	if err != nil {
		log.Fatalln(err)
	}
	// 建employees表
	// createTableBook(db)

	// 插入数据
	// db.Exec("INSERT INTO books (title, author, price) VALUES (?, ?, ?)", "生命", "david", 50)
	// db.Exec("INSERT INTO books (title, author, price) VALUES (?, ?, ?)", "大地", "david", 8)
	// db.Exec("INSERT INTO books (title, author, price) VALUES (?, ?, ?)", "海洋", "david", 93)
	// db.Exec("INSERT INTO books (title, author, price) VALUES (?, ?, ?)", "空气", "david", 40)

	// 1.使用Sqlx执行一个复杂的查询，例如查询价格大于 50 元的书籍，并将结果映射到 Book 结构体切片中，确保类型安全
	var books []Book
	db.Select(&books, "select * from books where price > 50")
	fmt.Println(books)
}

func createTableBook(db *sqlx.DB) {
	schema := `
	create table if not exists books (
	id int auto_increment primary key,
	title varchar(100),
	author varchar(100),
	price float )
	`
	db.MustExec(schema)
}
