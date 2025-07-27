package chap_3

import (
	"fmt"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

type Student struct {
	gorm.Model
	Name  string
	Age   uint8
	Grade string
}

func Connect() {
	dsn := "root:123456@tcp(127.0.0.1:3306)/gorm_test?charset=utf8mb4&parseTime=True&loc=Local"
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		fmt.Println(err)
		fmt.Println("Failed to connect")
	} else {
		fmt.Println("Mysql Connected")
	}

	// 1.创建student表
	db.AutoMigrate(&Student{})

	// 2.向 students 表中插入一条新记录，学生姓名为 "张三"，年龄为 20，年级为 "三年级"
	student := Student{Name: "张三", Age: 20, Grade: "三年级"}
	res := db.Create(&student)
	fmt.Println(res.RowsAffected)
	fmt.Println(res.Error)

	// 3.查询 students 表中所有年龄大于 18 岁的学生信息
	var students []Student
	db.Where("age > ?", 18).Find(&students)
	fmt.Println(students)

	// 4.将 students 表中姓名为 "张三" 的学生年级更新为 "四年级"
	db.Model(Student{Name: "张三"}).Where("name = ?", "张三").Update("grade", "四年级")

	//5.删除 students 表中年龄小于 15 岁的学生记录
	db.Where("age < ?", 15).Delete(&Student{})
}
