const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("MyStake", function () {
    let stake, rewardToken, stakeToken, owner, alice, bob;

    beforeEach(async () => {
        [owner, alice, bob] = await ethers.getSigners();

        // 部署测试用 ERC20 代币
        const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
        rewardToken = await ERC20Mock.deploy("Reward", "RWD", 1000000);
        await rewardToken.waitForDeployment();
        stakeToken = await ERC20Mock.deploy("Stake", "STK", 1000000);
        await stakeToken.waitForDeployment();

        // 给 Alice 和 Bob 发些代币
        let tx = await stakeToken.mint(alice.address, 10000);
        await tx.wait();
        tx = await stakeToken.mint(bob.address, 10000);
        await tx.wait();
        // 部署 MyStake
        const MyStake = await ethers.getContractFactory("MyStake");

        stake = await upgrades.deployProxy(
            MyStake,
            [rewardToken.target, 1, owner.address], // 初始化参数
            { initializer: "initialize", kind: "uups", }
        );
        await stake.waitForDeployment();

        // 给奖励池充点 token
        tx = await rewardToken.mint(stake.target, 1000000);
        await tx.wait();

        // 添加一个池子
        tx = await stake.addPool(stakeToken.target, 100, 1, 10);
        await tx.wait();
    });

    it("should allow staking and reward accrual", async () => {
        await stakeToken.connect(alice).approve(stake.target, 10000);

        let tx = await stake.connect(alice).stake(0, 10000);
        await tx.wait();

        const userInfo = await stake.userInfo(0, alice.address);
        expect(userInfo.amount).to.equal(10000);
    });

    it("should accrue rewards over time", async () => {
        await stakeToken.connect(alice).approve(stake.target, 10000);
        let tx = await stake.connect(alice).stake(0, 10000);
        await tx.wait();

        // 模拟挖 20 个区块
        for (let i = 0; i < 20; i++) {
            await ethers.provider.send("evm_mine", []);
        }

        const pending = await stake.pendingReward(0, alice.address);
        console.log("pending reward: ", pending)
        expect(pending).to.be.gt(0);
    });

    it("should allow claiming rewards", async () => {
        await stakeToken.connect(alice).approve(stake.target, 10000);
        let tx = await stake.connect(alice).stake(0, 10000);
        await tx.wait();

        await ethers.provider.send("evm_mine", []);
        await ethers.provider.send("evm_mine", []);

        const before = await rewardToken.balanceOf(alice.address);
        console.log("before: ", before)
        await stake.connect(alice).claim(0);
        const after = await rewardToken.balanceOf(alice.address);
        console.log("after: ", after);

        expect(after).to.be.gt(before);
    });

    it("should lock unstake requests", async () => {
        await stakeToken.connect(alice).approve(stake.target, 10000);
        let tx = await stake.connect(alice).stake(0, 10000);
        await tx.wait();

        await stake.connect(alice).requestUnstake(0, 5000);

        // 立即尝试提取应失败
        await expect(stake.connect(alice).withdrawUnstaked(0)).to.be.revertedWith("nothing to withdraw");

        // 等待 11 个区块
        for (let i = 0; i < 11; i++) {
            await ethers.provider.send("evm_mine", []);
        }

        await stake.connect(alice).withdrawUnstaked(0);

        const bal = await stakeToken.balanceOf(alice.address);
        console.log("bal:", bal);
        expect(bal).to.be.gt(0);
    });
});
