// test/WitcherX.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

const TITANX_ADDRESS = "0xF19308F923582A6f7c465e5CE7a9Dc1BEC6665B1";


describe("WitcherX", function () {
    let witcherX, witcherXStake, titanX;
    let owner, treasureAddress, account01, account02, account03, otherAccounts;
    let snapshotId;

    before(async function () {
        [owner, treasureAddress, account01, account02, account03, ...otherAccounts] = await ethers.getSigners();

        const WitcherX = await ethers.getContractFactory("contracts/WitcherX.sol:WitcherX");
        const TitanX = await ethers.getContractFactory("TitanX");
        const WitcherXStake = await ethers.getContractFactory("WitcherXStake");
        witcherX = await WitcherX.deploy(owner.address, TITANX_ADDRESS, treasureAddress);
        titanX = await TitanX.deploy();
        witcherXStake = await WitcherXStake.deploy(await witcherX.getAddress());
        witcherX.setStakingContract(await witcherXStake.getAddress());

    });

    // beforeEach(async function () {
    //     snapshotId = await ethers.provider.send("evm_snapshot", []);
    // });

    // afterEach(async function () {
    //     await ethers.provider.send("evm_revert", [snapshotId]);
    // });

    // it("Should deploy and set the initial values correctly", async function () {
    //     const tokenAmount = ethers.parseEther("1000000");

    //     await witcherX.connect(owner).approve(await witcherX.getAddress(), tokenAmount);
    //     await titanX.connect(owner).approve(await witcherX.getAddress(), tokenAmount);

    //     await witcherX.connect(owner).transfer(await witcherX.getAddress(), tokenAmount);
    //     await titanX.connect(owner).transfer(await witcherX.getAddress(), tokenAmount);


    // console.log("Saldo TitanX na kontrakcie WitcherX:", (await titanX.balanceOf(await witcherX.getAddress())));
    // console.log("Saldo WitcherX na kontrakcie WitcherX:", (await witcherX.balanceOf(await witcherX.getAddress())));

    // await witcherX.addLiquidity(tokenAmount, tokenAmount);
    // });

    it("Should handle transfers correctly", async function () {
        const transferAmount = ethers.parseEther("100");
        await witcherX.connect(owner).transfer(account01.address, transferAmount);
        // expect(await witcherX.balanceOf(account01.address)).to.equal(transferAmount);

        console.log("Saldo account01 przed transferem:", ethers.formatEther(await witcherX.balanceOf(account01.address)));
        await witcherX.connect(account01).transfer(account02.address, transferAmount);
        console.log("Saldo account01 po transferze:", ethers.formatEther(await witcherX.balanceOf(account01.address)));
        console.log("Saldo account02 po transferem:", ethers.formatEther(await witcherX.balanceOf(account02.address)));


        console.log("Balans treasure", ethers.formatEther(await witcherX.balanceOf(treasureAddress)));
        console.log("Balans stakingu", ethers.formatEther(await witcherX.balanceOf(await witcherXStake.getAddress())));

    });

});