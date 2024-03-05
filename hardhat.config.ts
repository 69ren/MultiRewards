import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
//import "@nomicfoundation/hardhat-foundry";
import { resolve } from "path";
import { config as dotenvConfig } from "dotenv";
dotenvConfig({ path: resolve(__dirname, "./.env") });

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      viaIR: true,
      optimizer: { enabled: true, runs: 1000 },
      evmVersion: "paris", // L2's do not support push0
      metadata: {
        bytecodeHash: "none",
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 250,
      initialBaseFeePerGas: 0,
      forking: {
        url: process.env.RPC_URL!,
      },
      accounts: [
        {
          privateKey: process.env.PRIVATE_KEY!,
          balance: "10000000000000000000000",
        },
      ],
    },
    opera: {
      url: process.env.RPC_URL!,
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: { opera: process.env.FTMSCAN_API_KEY! },
  },
};

export default config;
