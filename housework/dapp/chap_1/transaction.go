package chap_1

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

func Transaction() {
	client, err := ethclient.Dial("https://sepolia.infura.io/v3/a81e0f695c864003b31cce60340d867e")
	if err != nil {
		log.Fatal(err)
	}
	// 读取私钥
	privateKey, err := crypto.HexToECDSA("4315ce5be0484bf9803a1ddf914778d417ab559d4f40fdd77e15ea3826c71134")
	if err != nil {
		log.Fatal(err)
	}
	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		log.Fatal("error casting public key to ECDSA")
	}
	fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)
	// 读取我们应该用于帐户交易的随机数
	nonce, err := client.PendingNonceAt(context.Background(), fromAddress)
	if err != nil {
		log.Fatal(err)
	}

	value := big.NewInt(1000000000)
	gasLimit := uint64(21000)
	gasPrice, err := client.SuggestGasPrice(context.Background())
	if err != nil {
		log.Fatal(err)
	}

	// 发送ETH的账号
	toAddress := common.HexToAddress("0x2EfDa5F29F2c09A631D5eAcBb7bFEd13106048D7")
	// 交易
	tx := types.NewTx(&types.LegacyTx{
		Nonce:    nonce,
		To:       &toAddress,
		Value:    value,
		Gas:      gasLimit,
		GasPrice: gasPrice,
		Data:     nil,
	})
	// 使用发件人的私钥对事务进行签名
	chainID, err := client.NetworkID(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainID), privateKey)
	if err != nil {
		log.Fatal(err)
	}
	// 将交易广播到网络
	err = client.SendTransaction(context.Background(), signedTx)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("tx sent: %s", signedTx.Hash().Hex())

}

func GetBlockInfo() {
	client, err := ethclient.Dial("https://sepolia.infura.io/v3/a81e0f695c864003b31cce60340d867e")
	if err != nil {
		log.Fatal(err)
	}
	block, err := client.BlockByNumber(context.Background(), nil)
	if err != nil {
		log.Fatal(err)
	}
	// 哈希
	fmt.Println(block.Hash().Hex())
	// 区块号
	fmt.Println(block.Number())
	// 时间戳
	fmt.Println(block.Time())
	// 交易数量
	fmt.Println(block.Transactions().Len())
}
