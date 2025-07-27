package chap_3

import (
	"fmt"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

type Account struct {
	gorm.Model
	Name    string
	Balance uint
}

type Transaction struct {
	gorm.Model
	FromAccountID uint
	ToAccountID   uint
	Amount        uint
}

func TransTest() {
	dsn := "root:123456@tcp(127.0.0.1:3306)/gorm_test?charset=utf8mb4&parseTime=True&loc=Local"
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		fmt.Println(err)
		fmt.Println("Failed to connect")
	} else {
		fmt.Println("Mysql Connected")
	}

	db.AutoMigrate(&Account{})
	db.AutoMigrate(&Transaction{})

	// 插入数据
	// accounts := []Account{
	// 	{Name: "A", Balance: 200},
	// 	{Name: "B", Balance: 20},
	// }
	// db.Create(accounts)

	tx := db.Begin()
	var accountA Account
	tx.Where("name = ?", "A").Find(&accountA)
	if accountA.Balance < 100 {
		tx.Rollback()
		return
	}
	// 减少A账户100
	// tx.Model(&Account{}).Where("name = ?", "A").Update("balance", accountA.Balance-100)
	tx.Model(&accountA).Update("balance", accountA.Balance-100)
	// 增加B账户100
	var accountB Account
	tx.Where("name = ?", "B").Find(&accountB)
	tx.Model(&accountB).Update("balance", accountB.Balance+100)
	// 增加transction表记录
	tx.Create(&Transaction{FromAccountID: accountA.ID, ToAccountID: accountB.ID, Amount: 100})
	tx.Commit()

}
