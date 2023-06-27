const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("StableMarketGasless", function () {
  let accounts;
  let owner;
  let owner2;
  let sponsor;

  let usdt;
  let htg;
  let multiple = 1000000;

  let stableMarketGasless;

  it("should be deployed", async () => {
    accounts = await ethers.getSigners();

    owner = await accounts[0];
    owner2 = await accounts[1];
    sponsor = await accounts[4];

    const StableUSD = await ethers.getContractFactory("Stable");
    usdt = await StableUSD.deploy("USD");
    const StableHTG = await ethers.getContractFactory("Stable");
    htg = await StableHTG.deploy("HTG");

    const StableMarket = await ethers.getContractFactory("StableMarketGasless");
    stableMarketGasless = await StableMarket.deploy(
      usdt.target,
      accounts[10].getAddress()
    );

    console.log("USDT : ", usdt.target);
    console.log("HTG : ", htg.target);
    console.log("Stable Market : ", stableMarketGasless.target);
  });

  it("should set the correct owner", async () => {
    const owner = await stableMarketGasless.owner();

    expect(await accounts[0].getAddress()).to.equal(owner);
  });

  it("should set the correct manager address", async () => {
    const manager = await stableMarketGasless.managers(
      await accounts[0].getAddress()
    );
    expect(manager).to.equal(true);
  });

  it("should set the correct admin address", async () => {
    const admin = await stableMarketGasless.admins(
      await accounts[0].getAddress()
    );
    expect(admin).to.equal(true);
  });

  it("should set the correct assistant address", async () => {
    const assistant = await stableMarketGasless.assistants(
      await accounts[0].getAddress()
    );
    expect(assistant).to.equal(true);
  });

  it("should set the correct membersFee ", async () => {
    const membersFee = await stableMarketGasless.membersFee(
      await accounts[0].getAddress()
    );
    expect(membersFee).to.equal(0);
  });

  it("should set the correct sellersFee ", async () => {
    const sellersFee = await stableMarketGasless.sellersFee(
      await accounts[0].getAddress()
    );
    expect(sellersFee).to.equal(0);
  });

  it("should set the correct masterTax", async () => {
    const masterTax = await stableMarketGasless.masterTax();

    expect(await accounts[0].getAddress()).to.equal(masterTax);
  });

  it("should set the correct validStablecoin", async () => {
    const validStablecoin = await stableMarketGasless.validStablecoin();

    expect(validStablecoin).to.equal(usdt.target);
  });

  it("should set the correct htg", async () => {
    await stableMarketGasless.addStable(htg.target);
    const stable = await stableMarketGasless.acceptStables(htg.target);
    expect(stable.addr).to.equal(htg.target);
  });

  it("should set the  correct 0x00000000000..", async () => {
    await stableMarketGasless.addStable(await accounts[11].getAddress());
    await stableMarketGasless.removeStable(await accounts[11].getAddress());
    const stable = await stableMarketGasless.acceptStables(
      await accounts[11].getAddress()
    );
    expect(stable.addr).to.equal("0x0000000000000000000000000000000000000000");
  });

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  it("should minted 1000 usd to owner 1", async () => {
    await usdt.mint(owner, 1000000000);
    const balance = await usdt.balanceOf(owner);

    expect(balance.toString()).to.equal("1000000000");
  });

  it("should minted 100000 htg to owner 1", async () => {
    await htg.mint(owner, 100000000000);
    const balance = await htg.balanceOf(owner);

    expect(balance.toString()).to.equal("100000000000");
  });

  it("should be allowed 1000000000 usd from owner 1 to Smart market", async () => {
    await usdt.approve(stableMarketGasless.target, 1000000000000);
    const allowance = await usdt.allowance(owner, stableMarketGasless.target);
    expect(allowance.toString()).to.equal("1000000000000");
  });

  it("should be allowed 1000000000 htg from owner 1 to Smart market", async () => {
    await htg.approve(stableMarketGasless.target, 1000000000000);
    const allowance = await htg.allowance(owner, stableMarketGasless.target);
    expect(allowance.toString()).to.equal("1000000000000");
  });

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  it("should be minted 1000 usd to owner 2", async () => {
    await usdt.mint(owner2, 1000000000);
    const balance = await usdt.balanceOf(owner2);

    expect(balance.toString()).to.equal("1000000000");
  });

  it("should be minted 100000 htg to owner 2", async () => {
    await htg.mint(owner2, 100000000000);
    const balance = await htg.balanceOf(owner2);

    expect(balance.toString()).to.equal("100000000000");
  });

  it("should be allowed  1000000000 usd from owner 2 to Smart market", async () => {
    await usdt.connect(owner2).approve(stableMarketGasless.target, 1000000000);
    const allowance = await usdt.allowance(owner2, stableMarketGasless.target);
    expect(allowance.toString()).to.equal("1000000000");
  });

  it("should be allowed  1000000000 htg from owner 2 to Smart market", async () => {
    await htg.connect(owner2).approve(stableMarketGasless.target, 1000000000);
    const allowance = await htg.allowance(owner2, stableMarketGasless.target);
    expect(allowance.toString()).to.equal("1000000000");
  });

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  it("should get the correct amount USDT of the Offer", async () => {
    const idTr = 1;
    const amount = 100 * multiple;
    const rate = 50;

    await stableMarketGasless
      .connect(owner)
      .bidOffer(idTr, amount, rate, htg.target);

    const offer = await stableMarketGasless.getOneTrade(idTr);

    expect(offer[4].toString()).to.equal(`${amount}`);
  });

  it("should get the correct amount = 110 for the Offer", async () => {
    const idTr = 1;
    const amount = 10 * multiple;

    await stableMarketGasless.connect(owner).addUsdtBidOffer(idTr, amount);

    const offer = await stableMarketGasless.getOneTrade(idTr);

    expect(offer[3].toString()).to.equal(`${110000000}`);
  });

  it("should get the correct rate = 60 for the Offer", async () => {
    const idTr = 1;
    const rate = 60;

    await stableMarketGasless.connect(owner).updateBidOffer(idTr, rate);

    const offer = await stableMarketGasless.getOneTrade(idTr);

    expect(offer[5].toString()).to.equal(`${rate}`);
  });

  it("should get the correct amount of USDT remain", async () => {
    const idTr = 1;
    const amount = 4 * multiple;
    const offer0 = await stableMarketGasless.getOneTrade(idTr);

    await stableMarketGasless
      .connect(owner2)
      .takeBidOffer(idTr, amount, sponsor.getAddress());

    const offer = await stableMarketGasless.getOneTrade(idTr);

    expect(parseInt(offer[3].toString())).to.equal(
      parseInt(offer0[3].toString()) - amount
    );
  });
  it("should get the correct amount = 0 && initAmount = 110000000 USDT remain", async () => {
    const idTr = 1;

    await stableMarketGasless.connect(owner).cancelOffer(idTr);

    const offer = await stableMarketGasless.getOneTrade(idTr);

    expect(parseInt(offer[3].toString())).to.equal(0);
    expect(parseInt(offer[4].toString())).to.equal(110000000);
  });

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  it("should get the correct amount HTG of the Offer", async () => {
    const idTr = 2;
    const amount = 1000 * multiple;
    const rate = 20;

    await stableMarketGasless
      .connect(owner)
      .askOffer(idTr, amount, rate, htg.target);

    const offer = await stableMarketGasless.getOneTrade(idTr);

    expect(offer[4].toString()).to.equal(`${amount}`);
  });

  it("should get the correct amount = 2000 HTG for the Offer", async () => {
    const idTr = 2;
    const amount = 1000 * multiple;

    await stableMarketGasless.connect(owner).addStableAskOffer(idTr, amount);

    const offer = await stableMarketGasless.getOneTrade(idTr);

    expect(offer[3].toString()).to.equal(`2000000000`);
  });

  it("should get the correct rate = 60 for the Offer", async () => {
    const idTr = 2;
    const rate = 60;

    await stableMarketGasless.connect(owner).updateAskOffer(idTr, rate);

    const offer = await stableMarketGasless.getOneTrade(idTr);

    expect(offer[5].toString()).to.equal(`${rate}`);
  });

  it("should get the correct amount of HTG remain", async () => {
    const idTr = 2;
    const amount = 10 * multiple;
    const rate = 60;

    const offer0 = await stableMarketGasless.getOneTrade(idTr);

    await stableMarketGasless
      .connect(owner2)
      .takeAskOffer(idTr, amount, sponsor.getAddress());

    const offer = await stableMarketGasless.getOneTrade(idTr);

    expect(parseInt(offer[3].toString())).to.equal(
      parseInt(offer0[3].toString()) - amount * rate
    );
  });
  it("should get the correct amount = 0 && initAmount = 2000000000 HTG remain", async () => {
    const idTr = 2;

    await stableMarketGasless.connect(owner).cancelOffer(idTr);

    const offer = await stableMarketGasless.getOneTrade(idTr);

    expect(parseInt(offer[3].toString())).to.equal(0);
    expect(parseInt(offer[4].toString())).to.equal(2000000000);
  });
});
