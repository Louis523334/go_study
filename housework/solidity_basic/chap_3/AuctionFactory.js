const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("AuctionFactory", function () {
  this.timeout(1200000);
  let owner, bidder1, bidder2;
  let myNFT, auctionFactory, auctionFactoryAddress, myNFTAddress;
  const tokenAddress = "0x779877A7B0D9E8603169DdbD7836e478b4624789";

  beforeEach(async function () {
    // [owner, bidder1, bidder2] = await ethers.getSigners();
    [owner, bidder1] = await ethers.getSigners();
    // console.log("Owner:", owner.address);
    // console.log("bidder1:", bidder1.address);

    // 部署 NFT 合约
    const MyNFT = await ethers.getContractFactory("MyNFT");
    myNFT = await MyNFT.deploy();
    await myNFT.waitForDeployment();
    myNFTAddress = await myNFT.getAddress();

    // Mint 一个 NFT 给 owner
    const tx = await myNFT.mint(owner.address, 0);
    await tx.wait();  // 等待交易确认
    const ownerNft = await myNFT.ownerOf(0);
    console.log("owner of :", ownerNft);

    // 部署 AuctionFactory，传入 myNFT 地址
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    auctionFactory = await AuctionFactory.deploy(myNFTAddress);
    await auctionFactory.waitForDeployment();
    auctionFactoryAddress = await auctionFactory.getAddress();

    // 设置 AuctionFactory 的 NFT 地址 (你合约里写死了，这里建议改为可传入)
  });

  // it("should create auction for tokenId", async function () {
  //   const tx = await myNFT.approve(to=auctionFactoryAddress, tokenId=0);
  //   await tx.wait();
  //   await auctionFactory.createAuction(0);
    
  //   const auctionAddress = await auctionFactory.getAuction(0);
  //   expect(auctionAddress).to.be.properAddress;
  // });
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

  it("should deploy auction and accept bids", async function () {
    // approve and create auction
    const tx = await myNFT.approve(to=auctionFactoryAddress, tokenId=0);
    await tx.wait();
    const createAuction = await auctionFactory.createAuction(0);
    await createAuction.wait();

    const auctionAddress = await auctionFactory.getAuction(0);
    const MyAuction = await ethers.getContractFactory("MyAuction");
    const auction = await MyAuction.attach(auctionAddress);
    // const ownerNft = await myNFT.ownerOf(0);
    // console.log("owner of :", ownerNft);

    const highestBidBefore = await auction.getHighestBid();
    expect(highestBidBefore).to.equal(0);

    // 给拍卖合约权限转账
    let amount = ethers.parseUnits("0.000000001", 18); // decimals 根据代币决定
    const token = await ethers.getContractAt("IERC20", tokenAddress);

    const txApproveToken = await token.connect(bidder1).approve(auctionAddress, amount);
    await txApproveToken.wait();
    // 让 bidder1 出价
    const txBid = await auction.connect(bidder1).bidToken(amount, tokenAddress);
    await txBid.wait();

    let newHighestBidder = await auction.getHighestBid();
    console.log("highestBid is: ", newHighestBidder)
    // expect(newHighestBidder).to.be.gt(0);

    // 快进时间
    // await ethers.provider.send("evm_increaseTime", [31]); // 31 秒
    // await ethers.provider.send("evm_mine");


    // owner再使用代币拍卖
    amount = ethers.parseUnits("0.000000002", 18);
    const txApproveToken2 = await token.connect(owner).approve(auctionAddress, amount);
    await txApproveToken2.wait();
    const txBidToken = await auction.connect(owner).bidToken(amount, tokenAddress);
    await txBidToken.wait();
    newHighestBidder = await auction.getHighestBid();
    console.log("highestBid is: ", newHighestBidder)

    // 等待20秒
    await delay(80000);

    // 检查拍卖是否结束
    const isOver = await auction.isOver();
    expect(isOver).to.equal(true);

    // finalize拍卖
    const txFinalize = await auction.finalizeAuction();
    await txFinalize.wait();
    const ownerNft2 = await myNFT.ownerOf(0);
    console.log("owner of :", ownerNft2);
    expect(await myNFT.ownerOf(0)).to.equal(owner.address);

    const txWithdraw= await auction.connect(bidder1).withdraw();
    await txWithdraw.wait();

    const balanceOwner = await auction.connect(owner).checkPendingReturns();
    const balanceBidder = await auction.connect(owner).checkPendingReturns();

    expect(balanceOwner).to.equal(0);
    expect(balanceBidder).to.equal(0);

  });

//   it("should finalize auction after duration", async function () {
//     await myNFT.approve(auctionFactory.address, 0);
//     await auctionFactory.createAuction(0, 0, 30, myNFT.address);

//     const auctionAddress = await auctionFactory.getAuction(0);
//     const MyAuction = await ethers.getContractFactory("MyAuction");
//     const auction = await MyAuction.attach(auctionAddress);

//     // 出价
//     await auction.connect(bidder1).bid({ value: ethers.utils.parseEther("1") });

//     // 快进时间
//     await ethers.provider.send("evm_increaseTime", [31]); // 31 秒
//     await ethers.provider.send("evm_mine");

//     const isOver = await auction.isOver();
//     expect(isOver).to.equal(true);

//     // finalize
//     await auction.finalizeAuction();
//     expect(await myNFT.ownerOf(0)).to.equal(bidder1.address);
//   });
});
