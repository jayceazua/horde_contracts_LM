import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";

dotenv.config();

const infura_api_key = process.env.INFURA_API_KEY;
const privateKey = process.env.PRIVATE_KEY;
const mnemonic = process.env.MNEMONIC;

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.15",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  paths: {
    cache: "./build/cache",
    artifacts: "./build/artifacts",
  },
  typechain: {
    outDir: "./build/typechain",
  },
  networks: {
    bsc_test: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: privateKey !== undefined ? [privateKey] : [],
    },
    bsc_main: {
      url: "https://bsc-dataseed1.binance.org",
      accounts: privateKey !== undefined ? [privateKey] : [],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: "61WHEI8V4PCXKWY664C5W4XV1RGYTFUGMR", //bsc_api
  },
};

export default config;
