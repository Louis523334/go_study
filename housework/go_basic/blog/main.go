package main

import (
	databse "github.com/Louis523334/blog/database"
	"github.com/Louis523334/blog/router"
)

func main() {
	databse.Connect()

	r := router.SetupRouter()
	// Listen and Server in 0.0.0.0:8080
	r.Run(":8080")

}
