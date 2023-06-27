// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // const stable = await hre.ethers.deployContract("Stable", ["HTG"]);
  // await stable.waitForDeployment();
  // console.log(`deployed to htg ${stable.target}`);
  // const stable = await hre.ethers.deployContract("StableMarketGasless", [
  //   "0xAcDe43b9E5f72a4F554D4346e69e8e7AC8F352f0",
  //   "0x69015912AA33720b842dCD6aC059Ed623F28d9f7",
  // ]);
  // await stable.waitForDeployment();
  // console.log(`deployed to ${stable.target}`);
  // const StableMarket = await hre.ethers.getContractFactory(
  //   "StableMarketGasless"
  // );
  // const stableMarket = await StableMarket.deploy(
  //   "0xAcDe43b9E5f72a4F554D4346e69e8e7AC8F352f0",
  //   "0x69015912AA33720b842dCD6aC059Ed623F28d9f7"
  // );
  // const stableMarket = await StableMarket.deploy(
  //   "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
  //   "0xf0511f123164602042ab2bCF02111fA5D3Fe97CD"
  // );
  // await stableMarket.deployed();
  // console.log(`deployed to ${stableMarket.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
