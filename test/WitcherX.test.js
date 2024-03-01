// test/WitcherX.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

const TITANX_ADDRESS = "0xF19308F923582A6f7c465e5CE7a9Dc1BEC6665B1";


describe("WitcherX", function () {
    let witcherX, witcherXStake;
    let owner, account01, account02, account03, account04, otherAccounts;
    let snapshotId;

    before(async function () {
        [owner, account01, account02, account03, account04, ...otherAccounts] = await ethers.getSigners();

        const WitcherX = await ethers.getContractFactory("contracts/WitcherX.sol:WitcherX");
        const WitcherXStake = await ethers.getContractFactory("WitcherXStake");
        witcherX = await WitcherX.deploy(owner.address, TITANX_ADDRESS);
        witcherXStake = await WitcherXStake.deploy(await witcherX.getAddress());
    });

    // beforeEach(async function () {
    //     snapshotId = await ethers.provider.send("evm_snapshot", []);
    // });

    // afterEach(async function () {
    //     await ethers.provider.send("evm_revert", [snapshotId]);
    // });

    it("Should deploy and set the initial values correctly", async function () {
        const mintedAmount = ethers.parseEther("333333333333");

        expect(await witcherX.owner()).to.equal(owner.address);
        expect(await witcherX.balanceOf(owner.address)).to.be.eq(mintedAmount);
    });

    it("Should handle transfers correctly", async function () {
        const transferAmount = ethers.parseEther("100");
        await witcherX.connect(owner).transfer(account01.address, transferAmount);
        expect(await witcherX.balanceOf(account01.address)).to.equal(transferAmount);

        await witcherX.connect(account01).transfer(account02.address, transferAmount);
        // console.log(await witcherX.balanceOf(account02.address));

    });

});