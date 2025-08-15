package test

import (
	"context"
	"fmt"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
)

func GetTx() {
	client, err := ethclient.Dial("https://sepolia.infura.io/v3/a81e0f695c864003b31cce60340d867e")
	if err != nil {
		log.Fatal(err)
	}
	chainID, err := client.ChainID(context.Background())
	if err != nil {
		log.Fatal(err)
	}

	blockNumber := big.NewInt(5671744)
	// 获取区块信息
	block, err := client.BlockByNumber(context.Background(), blockNumber)
	if err != nil {
		log.Fatal(err)
	}
	// 查看交易
	for _, tx := range block.Transactions() {
		//fmt.Println(tx.Hash().Hex())
		//fmt.Println(tx.Time())
		//fmt.Println(tx.BlobGas())
		//fmt.Println(tx.GasPrice())
		//fmt.Println(tx.Nonce())
		//fmt.Println(tx.BlobGasFeeCap())
		//fmt.Println(tx.Data())
		//fmt.Println("------------------------")
		if sender, err := types.Sender(types.NewEIP155Signer(chainID), tx); err == nil {
			fmt.Println("sender", sender.Hex()) // 0x0fD081e3Bb178dc45c0cb23202069ddA57064258
		}
		receipt, err := client.TransactionReceipt(context.Background(), tx.Hash())
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(receipt.Status)
		fmt.Println(receipt.Logs)
	}
}
