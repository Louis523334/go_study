package test

import (
	"context"
	"fmt"
	"log"
	"math"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

func GetBalance() {
	client, err := ethclient.Dial("https://sepolia.infura.io/v3/a81e0f695c864003b31cce60340d867e")
	if err != nil {
		log.Fatal(err)
	}
	account := common.HexToAddress("0x2EfDa5F29F2c09A631D5eAcBb7bFEd13106048D7")
	// 指定为nil则为最新余额
	balance, err := client.BalanceAt(context.Background(), account, nil)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(balance)
	// 传入区块高度获取指定区块的余额
	//blockNumber := big.NewInt(123456)
	//balance, err = client.BalanceAt(context.Background(), account, blockNumber)
	//if err != nil {
	//	log.Fatal(err)
	//}
	//fmt.Println(balance)

	fbalance := new(big.Float)
	fbalance.SetString(balance.String())
	ethValue := new(big.Float).Quo(fbalance, big.NewFloat(math.Pow10(18)))
	fmt.Println(ethValue)
}
