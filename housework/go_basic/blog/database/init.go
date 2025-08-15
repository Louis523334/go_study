package databse

import (
	"fmt"
	"log"
	"time"

	"github.com/Louis523334/blog/model"
	"github.com/spf13/viper"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

type Database struct {
	Host     string
	Port     int
	User     string
	Password string
	Name     string
	Charset  string
}

type Config struct {
	Database Database
}

var DB *gorm.DB

func initDatabaseConfig() Config {
	var conf Config
	viper.SetConfigName("db") // 不需要写后缀
	viper.SetConfigType("yaml")
	viper.AddConfigPath("config") // 当前目录查找

	err := viper.ReadInConfig()
	if err != nil {
		log.Fatalf("配置文件读取失败: %v", err)
	}

	err = viper.Unmarshal(&conf)
	if err != nil {
		log.Fatalf("配置解析失败: %v", err)
	}
	fmt.Println(conf.Database.Host)

	log.Println("配置文件读取成功")

	return conf
}

func Connect() {
	conf := initDatabaseConfig()
	dsn := fmt.Sprintf(
		"%s:%s@tcp(%s:%d)/%s?charset=%s&parseTime=True&loc=Local",
		conf.Database.User,
		conf.Database.Password,
		conf.Database.Host,
		conf.Database.Port,
		conf.Database.Name,
		conf.Database.Charset,
	)
	db, _ := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	// 设置连接池
	sqlDB, err := db.DB()
	if err != nil {
		log.Fatalf("获取数据库对象失败: %v", err)
	}

	// ✅ 设置连接池参数
	sqlDB.SetMaxIdleConns(10)                  // 最大空闲连接数
	sqlDB.SetMaxOpenConns(100)                 // 最大打开连接数
	sqlDB.SetConnMaxLifetime(30 * time.Minute) // 每个连接的最长生命周期

	log.Println("数据库连接成功")

	DB = db
	// 建表
	DB.Config.DisableForeignKeyConstraintWhenMigrating = true
	DB.AutoMigrate(&model.User{}, &model.Post{}, &model.Comment{})
}
