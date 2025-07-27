package chap_3

import (
	"fmt"
	"log"

	_ "github.com/go-sql-driver/mysql" // 或 postgres/sqlite 等驱动
	"github.com/jmoiron/sqlx"
)

type Employee struct {
	ID         uint    `db:"id"`
	Name       string  `db:"name"`
	Department string  `db:"department"`
	Salary     float64 `db:"salary"`
}

func EmployeeTest() {
	db, err := sqlx.Connect("mysql", "root:123456@tcp(127.0.0.1:3306)/gorm_test")
	if err != nil {
		log.Fatalln(err)
	}
	// 建employees表
	// createTable(db)

	// 插入数据
	// db.Exec("INSERT INTO employees (name, department, salary) VALUES (?, ?, ?)", "张三", "技术部", 5000)
	// db.Exec("INSERT INTO employees (name, department, salary) VALUES (?, ?, ?)", "李四", "人力部", 8000)
	// db.Exec("INSERT INTO employees (name, department, salary) VALUES (?, ?, ?)", "王五", "技术部", 9000)
	// db.Exec("INSERT INTO employees (name, department, salary) VALUES (?, ?, ?)", "张明", "管理部", 4000)

	// 1.使用Sqlx查询 employees 表中所有部门为 "技术部" 的员工信息，并将结果映射到一个自定义的 Employee 结构体切片中
	var employeesTech []Employee
	db.Select(&employeesTech, "select * from employees where department = '技术部'")
	fmt.Println(employeesTech)
	// 2.使用Sqlx查询 employees 表中工资最高的员工信息，并将结果映射到一个 Employee 结构体中
	var employeeHighestSal Employee
	db.Get(&employeeHighestSal, "select * from employees order by salary desc limit 1")
	fmt.Println(employeeHighestSal)
}

func createTable(db *sqlx.DB) {
	schema := `
	create table if not exists employees (
	id int auto_increment primary key,
	name varchar(100),
	department varchar(100),
	salary float )
	`
	db.MustExec(schema)
}
