const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LLToken", function () {
    let TokenA, TokenB, tokenA, tokenB;
    let LLToken, llToken;
    let owner, user1, user2;

    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();

        // 部署两个 ERC20 token 用作池子
        TokenA = await ethers.getContractFactory("ERC20Mock"); // 需要一个 ERC20 Mock
        TokenB = await ethers.getContractFactory("ERC20Mock");
        tokenA = await TokenA.deploy("TokenA", "TKA", 100000);
        await tokenA.waitForDeployment();
        tokenB = await TokenB.deploy("TokenB", "TKB", 100000);
        await tokenB.waitForDeployment();
        // console.log(tokenA.target);
        // console.log(tokenB.target);

        // 部署 LLToken 合约
        LLToken = await ethers.getContractFactory("LLToken");
        llToken = await LLToken.deploy(tokenA.target, tokenB.target, "LLToken", "LL");
        await llToken.waitForDeployment();
        // console.log(llToken.target);

        // 给owner一些lltoken
        // const txTokenLL = await llToken.mint(owner.address, 10000);
        // await txTokenLL.wait()
        // console.log(await llToken.balanceOf(owner.address));

        // 给用户一些 tokenA 和 tokenB
        const txTokenA = await tokenA.transfer(user1.address, 10000);
        await txTokenA.wait();
        const txTokenB = await tokenB.transfer(user1.address, 10000);
        await txTokenB.wait();
        const txTokenA2 = await tokenA.transfer(user2.address, 10000);
        await txTokenA2.wait();
        const txTokenB2 = await tokenB.transfer(user2.address, 10000);
        await txTokenB2.wait();
        // console.log(await tokenA.balanceOf(user1.address));
        // console.log(await tokenB.balanceOf(user1.address));

        // 用户 approve 给 LLToken
        const txApproveTokenA = await tokenA.connect(user1).approve(llToken.target, 10000);
        await txApproveTokenA.wait();
        const txApproveTokenB = await tokenB.connect(user1).approve(llToken.target, 10000);
        await txApproveTokenB.wait();


    });

    // it("should apply tax on transfer", async function () {
    //     // const amount = ethers.utils.parseEther("100");
    //     // await llToken._mint(user1.address, amount); // 给用户 mint LLToken 用于测试
    //     // 设置税率
    //     const txSetTaxRate = await llToken.setTaxRate(50);
    //     await txSetTaxRate.wait();
    //     // 获取税率
    //     const taxRate = await llToken.getTaxRate();
    //     expect(taxRate).eq(50);
    //     // 设置过高税率, 应该会回退
    //     await expect(
    //         llToken.setTaxRate(101)
    //     ).to.be.reverted;
    //
    //     // 设置最大交易额
    //     const txSetMaxTxAmount = await llToken.setMaxTxAmount(4000);
    //     await txSetMaxTxAmount.wait();
    //     // 获取最大交易额
    //     const MaxTxAmount = await llToken.getMaxTxAmount();
    //     expect(MaxTxAmount).eq(4000);
    //
    //     // 设置最大交易次数
    //     const txSetMaxTxPerDay = await llToken.setMaxTxPerDay(3);
    //     await txSetMaxTxPerDay.wait();
    //     // 获取最大交易额
    //     const MaxTxPerDay = await llToken.getMaxTxPerDay();
    //     expect(MaxTxPerDay).eq(3);
    //
    //     // owner给user1转账1000个lltoken
    //     const txLLtoken = await llToken.connect(owner).transfer(user1.address, 1000);
    //     await txLLtoken.wait();
    //     console.log(await llToken.balanceOf(owner.address));
    //     // owner的lltoken数量
    //     const balanceOwner = await llToken.balanceOf(owner.address);
    //     // user1的lltoken数量
    //     const balanceUser1 = await llToken.balanceOf(user1.address);
    //     // llToken的合约数量
    //     const balanceContractLLtoken = await llToken.balanceOf(llToken.target);
    //     expect(balanceOwner).eq(8500);
    //     expect(balanceUser1).eq(1000);
    //     expect(balanceContractLLtoken).eq(500);
    //     // 检查最大交易额
    //     await expect(
    //         llToken.connect(owner).transfer(user1.address, 5000)
    //     ).to.be.reverted;
    //     console.log("taxt rate is: ", await llToken.getTaxRate());
    //     // 检查最大交易次数
    //     const txLLtoken1 = await llToken.connect(owner).transfer(user1.address, 10);
    //     await txLLtoken1.wait();
    //     const txLLtoken2 = await llToken.connect(owner).transfer(user1.address, 10);
    //     await txLLtoken2.wait();
    //     await expect(
    //         llToken.connect(owner).transfer(user1.address, 10)
    //     ).to.be.reverted;
    //     // 时间快进1天
    //     await network.provider.send("evm_increaseTime", [24 * 60 * 60]); // 快进一天（单位秒）
    //     await network.provider.send("evm_mine"); // 手动挖一个块，让时间生效
    //     // 重新交易
    //     const txLLtoken3 = await llToken.connect(owner).transfer(user1.address, 10);
    //     await txLLtoken3.wait();
    //
    // });

    it("should add liquidity initially", async () => {
        await llToken.connect(user1).addLiquidity(1000, 2000, 900, 1800);

        expect(await llToken.balanceOf(user1.address)).to.be.gt(0);

        const reserves = await llToken.getReserves();
        expect(reserves._reserveA).to.equal(1000);
        expect(reserves._reserveB).to.equal(2000);
    });

    it("should add liquidity proportionally", async () => {
        // 第一次加 1000 A + 2000 B
        await llToken.connect(user1).addLiquidity(1000, 2000, 900, 1800);
        console.log(await llToken.balanceOf(user1.address));

        // 再加 500 A + 1000 B（保持比例 1:2）
        await llToken.connect(user1).addLiquidity(500, 2000, 400, 800);

        const reserves = await llToken.getReserves();
        expect(reserves._reserveA).to.equal(1500);
        expect(reserves._reserveB).to.equal(3000);
    });

    it("should remove liquidity and return tokens", async () => {
        // 加流动性
        await llToken.connect(user1).addLiquidity(1000, 2000, 900, 1800);
        const lpBalance = await llToken.balanceOf(user1.address);

        // 移除流动性
        await llToken.connect(user1).removeLiquidity(lpBalance, 900, 1800);

        // 检查储备归零
        const reserves = await llToken.getReserves();
        expect(reserves._reserveA).to.equal(0);
        expect(reserves._reserveB).to.equal(0);

        // 检查 LP token 销毁
        expect(await llToken.balanceOf(user1.address)).to.equal(0);
    });

    it("should swap A for B", async function () {
        // user1 添加初始流动性 (1000 A + 2000 B)
        const txAddLiq = await llToken.connect(user1).addLiquidity(1000, 2000, 900, 1800);
        await txAddLiq.wait();

        const amountIn = 100n; // user1 用 100 A 来换 B
        const taxRate = await llToken.getTaxRate();

        // 预期输出量 (和合约里的计算公式保持一致)
        const reserves = await llToken.getReserves();
        const reserveA = reserves._reserveA;
        const reserveB = reserves._reserveB;

        const amountInWithFee = amountIn * (1000n - taxRate); // 手续费 0.3%
        const expectedOut =
            (amountInWithFee * reserveB) /
            (reserveA * 1000n + amountInWithFee);

        // 执行 swap
        const swapAforB = await llToken.connect(user1).swapAForB(amountIn, expectedOut - 1n);
        await swapAforB.wait();

        // 验证结果
        const newBalanceA = await tokenA.balanceOf(user1.address);
        const newBalanceB= await tokenB.balanceOf(user1.address);

        expect(newBalanceA).to.equal(10000n - 1000n - amountIn); // 初始转入池子 1000，再花 100
        expect(newBalanceB).to.equal(10000n - 2000n + expectedOut); // 初始转入池子 2000，再得到 B
        console.log(await tokenA.balanceOf(llToken.target));
        console.log(await tokenB.balanceOf(llToken.target));

        // 储备更新
        const reservesAfter = await llToken.getReserves();
        expect(reservesAfter._reserveA).to.equal(reserveA + amountIn);
        expect(reservesAfter._reserveB).to.equal(reserveB - expectedOut);
    });

    it("LP should earn fees after swaps", async function () {
        // ============ Step 1: user1 添加流动性 ============
        const lpA = 1000n;
        const lpB = 1000n;

        let tx = await tokenA.connect(user1).approve(llToken.target, lpA);
        await tx.wait();
        tx = await tokenB.connect(user1).approve(llToken.target, lpB);
        await tx.wait();
        tx = await llToken.connect(user1).addLiquidity(lpA, lpB, 900n, 900n);
        await tx.wait();

        const lpBalanceBefore = await llToken.balanceOf(user1.address);
        expect(lpBalanceBefore).to.be.gt(0n);

        // ============ Step 2: user2 进行 swap，产生手续费 ============
        const swapIn = 100n;
        tx = await tokenA.connect(user2).approve(llToken.target, swapIn);
        await tx.wait();
        tx = await llToken.connect(user2).swapAForB(swapIn, 0);
        await tx.wait();

        // 再来几次增加手续费
        tx = await tokenA.connect(user2).approve(llToken.target, swapIn);
        await tx.wait();
        tx = await llToken.connect(user2).swapAForB(swapIn, 0);
        await tx.wait();

        // ============ Step 3: user1 退出流动性 ============
        const reservesBeforeRemove = await llToken.getReserves();

        const lpBalance = await llToken.balanceOf(user1.address);
        tx = await llToken.connect(user1).removeLiquidity(lpBalance, 0, 0);
        await tx.wait();

        const finalBalanceA = await tokenA.balanceOf(user1.address);
        const finalBalanceB = await tokenB.balanceOf(user1.address);

        console.log("Final balance A:", finalBalanceA.toString());
        console.log("Final balance B:", finalBalanceB.toString());

        // ============ Step 4: 验证收益 ============
        // 初始投入 1000 + 1000，退出时应该比这个多
        expect(finalBalanceA).to.be.gt(10000n - lpA);
        expect(finalBalanceB).to.be.gt(10000n - lpB);

        // 并且池子储备应该减少
        const reservesAfterRemove = await llToken.getReserves();
        expect(reservesAfterRemove._reserveA).to.be.lt(reservesBeforeRemove._reserveA);
        expect(reservesAfterRemove._reserveB).to.be.lt(reservesBeforeRemove._reserveB);
    });




});
