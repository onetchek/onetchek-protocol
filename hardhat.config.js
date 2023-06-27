require("@nomicfoundation/hardhat-toolbox");

require("dotenv").config();

// npx hardhat compile
// npx hardhat run --network mumbai scripts/deploySM.js

module.exports = {
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: 0,
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.POLYGONURL,
      },
    },
    matic: {
      url: process.env.POLYGONURL,
      accounts: [process.env.PRIVATEKEY],
      chainId: 137,
    },
    mumbai: {
      url: process.env.MUMBAIURL,
      accounts: [process.env.PRIVATEKEY],
      chainId: 80001,
    },
    gnosis: {
      url: process.env.GNOSISURL,
      accounts: [process.env.PRIVATEKEY],
      chainId: 100,
    },
  },
  etherscan: {
    apiKey: {
      polygon: "FRESPWCDKGK7947Y3UH4GMIAJVK8QR4GP8",
    },
  },
  solidity: {
    version: "0.8.16",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    scripts: "./scripts",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 20000,
  },
};
