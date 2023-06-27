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
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  // it("should set the  correct --------", async () => {
  //   const idTr = 1;
  //   const amount = 100000000;
  //   const rate = 50;

  //   await stableMarketGasless.bidOffer(idTr, amount, rate, htg.target);

  //   const offer = await stableMarketGasless.trades(idTr);
  //   console.log(offer);
  // });

  // it("should set the correct assistant address", async () => {
  //   const assistant = await StableMarketGasless.assistant();
  //   expect(assistant).to.equal("0xYourManagerAddress");
  // });

  // it("should set the correct validStablecoin address", async () => {
  //   const validStablecoin = await StableMarketGasless.validStablecoin();
  //   expect(validStablecoin).to.equal("0xYourStablecoinAddress");
  // });

  // it("should be able to change the manager address", async () => {
  //   await StableMarketGasless.connect(accounts[0]).changeManager(
  //     await accounts[1].getAddress()
  //   );
  //   const newManager = await StableMarketGasless.manager();
  //   expect(newManager).to.equal(await accounts[1].getAddress());
  // });

  // it("should be able to change the assistant address", async () => {
  //   await StableMarketGasless.connect(accounts[0]).changeAssistant(
  //     await accounts[1].getAddress()
  //   );
  //   const newAssistant = await StableMarketGasless.assistant();
  //   expect(newAssistant).to.equal(await accounts[1].getAddress());
  // });

  // it("should be able to change the tax percentage", async () => {
  //   await StableMarketGasless.connect(accounts[0]).changeFee(5);
  //   const newPercent = await StableMarketGasless.percent();
  //   expect(newPercent.toNumber()).to.equal(5);
  // });

  // it("should be able to change the tax affiliate percentage", async () => {
  //   await StableMarketGasless.connect(accounts[0]).changeTaxAff(15);
  //   const newPercentAff = await StableMarketGasless.percentAff();
  //   expect(newPercentAff.toNumber()).to.equal(15);
  // });

  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.

  // async function deployit() {
  //   // Contracts are deployed using the first signer/account by default
  //   const [owner, otherAccount] = await ethers.getSigners();

  //   const StableMarket = await ethers.getContractFactory("StableMarketGasless");
  //   const stableMarket = await StableMarket.deploy(
  //     "0x208eE5C4C36f5e7d4c7DbEF5e13DA56e161DF26A",
  //     "0x69015912AA33720b842dCD6aC059Ed623F28d9f7"
  //   );

  //   return { stableMarket, owner, otherAccount };
  // }

  // describe("Deployment", function () {
  //   it("Should set the right unlockTime", async function () {
  //     const { stableMarket, owner, otherAccount } = await loadFixture(deployit);
  //     console.log(stableMarket.target);
  //     expect(1).to.equal(1);
  //   });

  //   it("Should set the right owner", async function () {
  //     const { lock, owner } = await loadFixture(deployOneYearLockFixture);

  //     expect(await lock.owner()).to.equal(owner.address);
  //   });

  //   // it("Should receive and store the funds to lock", async function () {
  //   //   const { lock, lockedAmount } = await loadFixture(
  //   //     deployOneYearLockFixture
  //   //   );

  //   //   expect(await ethers.provider.getBalance(lock.target)).to.equal(
  //   //     lockedAmount
  //   //   );
  //   // });

  //   // it("Should fail if the unlockTime is not in the future", async function () {
  //   //   // We don't use the fixture here because we want a different deployment
  //   //   const latestTime = await time.latest();
  //   //   const Lock = await ethers.getContractFactory("Lock");
  //   //   await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
  //   //     "Unlock time should be in the future"
  //   //   );
  //   // });
  // });

  // describe("Withdrawals", function () {
  //   describe("Validations", function () {
  //     it("Should revert with the right error if called too soon", async function () {
  //       const { lock } = await loadFixture(deployOneYearLockFixture);

  //       await expect(lock.withdraw()).to.be.revertedWith(
  //         "You can't withdraw yet"
  //       );
  //     });

  //     it("Should revert with the right error if called from another account", async function () {
  //       const { lock, unlockTime, otherAccount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       // We can increase the time in Hardhat Network
  //       await time.increaseTo(unlockTime);

  //       // We use lock.connect() to send a transaction from another account
  //       await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
  //         "You aren't the owner"
  //       );
  //     });

  //     it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
  //       const { lock, unlockTime } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       // Transactions are sent using the first signer by default
  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).not.to.be.reverted;
  //     });
  //   });

  //   describe("Events", function () {
  //     it("Should emit an event on withdrawals", async function () {
  //       const { lock, unlockTime, lockedAmount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw())
  //         .to.emit(lock, "Withdrawal")
  //         .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
  //     });
  //   });

  //   describe("Transfers", function () {
  //     it("Should transfer the funds to the owner", async function () {
  //       const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).to.changeEtherBalances(
  //         [owner, lock],
  //         [lockedAmount, -lockedAmount]
  //       );
  //     });
  //   });
  // });
});

class StableMarketGaslessTest {
  constructor() {
    this.ABI = [];
  }

  async init() {
    this.provider = ethers.provider;
    this.wallets = await ethers.getSigners();
    this.owner = this.wallets[0];
    this.trustedForwarder = this.wallets[1].address;
    this.validStablecoin = this.wallets[2].address;

    const StableMarketGaslessFactory = await ethers.getContractFactory(
      "StableMarketGasless",
      this.owner
    );
    this.stableMarketGasless = await StableMarketGaslessFactory.deploy(
      this.validStablecoin,
      this.trustedForwarder
    );
    await this.stableMarketGasless.deployed();
  }

  async testAddStable() {
    const stablecoinAddress = this.wallets[3].address;
    await this.stableMarketGasless.addStable(stablecoinAddress);
    const stable = await this.stableMarketGasless.acceptStables(
      stablecoinAddress
    );
    expect(stable.addr).to.equal(stablecoinAddress);
  }

  async testRemoveStable() {
    const stablecoinAddress = this.wallets[4].address;
    await this.stableMarketGasless.addStable(stablecoinAddress);
    await this.stableMarketGasless.removeStable(stablecoinAddress);
    const stable = await this.stableMarketGasless.acceptStables(
      stablecoinAddress
    );
    expect(stable.addr).to.equal(ethers.constants.AddressZero);
  }

  async testAddAdmin() {
    const adminAddress = this.wallets[5].address;
    await this.stableMarketGasless.addAdmin(adminAddress);
    const isAdmin = await this.stableMarketGasless.admins(adminAddress);
    expect(isAdmin).to.equal(true);
  }

  async testRemoveAdmin() {
    const adminAddress = this.wallets[6].address;
    await this.stableMarketGasless.addAdmin(adminAddress);
    await this.stableMarketGasless.removeAdmin(adminAddress);
    const isAdmin = await this.stableMarketGasless.admins(adminAddress);
    expect(isAdmin).to.equal(false);
  }

  async testAddManager() {
    const managerAddress = this.wallets[7].address;
    await this.stableMarketGasless.addManager(managerAddress);
    const isManager = await this.stableMarketGasless.managers(managerAddress);
    expect(isManager).to.equal(true);
  }

  async testRemoveManager() {
    const managerAddress = this.wallets[8].address;
    await this.stableMarketGasless.addManager(managerAddress);
    await this.stableMarketGasless.removeManager(managerAddress);
    const isManager = await this.stableMarketGasless.managers(managerAddress);
    expect(isManager).to.equal(false);
  }

  async testAddAssistant() {
    const assistantAddress = this.wallets[9].address;
    await this.stableMarketGasless.addAssistant(assistantAddress);
    const isAssistant = await this.stableMarketGasless.assistants(
      assistantAddress
    );
    expect(isAssistant).to.equal(true);
  }

  async testRemoveAssistant() {
    const assistantAddress = this.wallets[10].address;
    await this.stableMarketGasless.addAssistant(assistantAddress);
    await this.stableMarketGasless.removeAssistant(assistantAddress);
    const isAssistant = await this.stableMarketGasless.assistants(
      assistantAddress
    );
    expect(isAssistant).to.equal(false);
  }

  async testChangeMasterTaxAddress() {
    const newMasterTax = this.wallets[11].address;
    await this.stableMarketGasless.changeMasterTaxAddress(newMasterTax);
    const masterTax = await this.stableMarketGasless.masterTax();
    expect(masterTax).to.equal(newMasterTax);
  }

  async testBidOffer() {
    const [_, user] = await ethers.getSigners();
    const idTr = 1;
    const amount = 1000;
    const rate = 5;
    const stable = "0x6ab707Aca953eDAeFBc4fD23bA73294241490620";

    await this.stableMarketGasless
      .connect(user)
      .bidOffer(idTr, amount, rate, stable);
  }

  async testAskOffer() {
    const [_, user] = await ethers.getSigners();
    const idTr = 1;
    const amount = 1000;
    const rate = 5;
    const stable = "0x6ab707Aca953eDAeFBc4fD23bA73294241490620";

    await this.stableMarketGasless
      .connect(user)
      .askOffer(idTr, amount, rate, stable);
  }

  async testUpdateBidOffer() {
    const [_, user] = await ethers.getSigners();
    const tradeId = 1;
    const rate = 6;

    await this.stableMarketGasless.connect(user).updateBidOffer(tradeId, rate);
  }

  async testUpdateAskOffer() {
    const [_, user] = await ethers.getSigners();
    const tradeId = 1;
    const rate = 6;

    await this.stableMarketGasless.connect(user).updateAskOffer(tradeId, rate);
  }

  async testTakeBidOffer() {
    const [_, user, sponsor] = await ethers.getSigners();
    const tradeId = 1;
    const amount = 1000;

    await this.stableMarketGasless
      .connect(user)
      .takeBidOffer(tradeId, amount, sponsor.address);
  }

  async testTakeAskOffer() {
    const [_, user, sponsor] = await ethers.getSigners();
    const tradeId = 1;
    const amount = 1000;

    await this.stableMarketGasless
      .connect(user)
      .takeAskOffer(tradeId, amount, sponsor.address);
  }

  async testCancelOffer() {
    const [_, user] = await ethers.getSigners();
    const tradeId = 1;

    await this.stableMarketGasless.connect(user).cancelOffer(tradeId);
  }

  async testWithdrawBid911() {
    const [owner] = await ethers.getSigners();
    const all = false;
    const amount = 1000;

    await this.stableMarketGasless.connect(owner).withdrawBid911(all, amount);
  }

  async testWithdrawAsk911() {
    const [owner] = await ethers.getSigners();
    const stable = "0x6ab707Aca953eDAeFBc4fD23bA73294241490620";
    const all = false;
    const amount = 1000;

    await this.stableMarketGasless
      .connect(owner)
      .withdrawAsk911(stable, all, amount);
  }

  async testWithdrawAny() {
    const [owner] = await ethers.getSigners();
    const token = "0x6ab707Aca953eDAeFBc4fD23bA73294241490620";
    const amount = 1000;

    await this.stableMarketGasless.connect(owner).withdrawAny(token, amount);
  }
}

// (async () => {
//   const stableMarketGaslessTest = new StableMarketGaslessTest();
//   await stableMarketGaslessTest.init();
//   await stableMarketGaslessTest.testAddStable();
//   await stableMarketGaslessTest.testRemoveStable();
//   await stableMarketGaslessTest.testAddAdmin();
//   await stableMarketGaslessTest.testRemoveAdmin();
//   await stableMarketGaslessTest.testAddManager();
//   await stableMarketGaslessTest.testRemoveManager();
//   await stableMarketGaslessTest.testAddAssistant();
//   await stableMarketGaslessTest.testRemoveAssistant();
//   await stableMarketGaslessTest.testChangeMasterTaxAddress();
//   console.log("All tests passed");
// })();
