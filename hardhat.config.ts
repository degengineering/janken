import { type HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-viem"; // <-- this injects hre.viem
import "@typechain/hardhat";            // <-- for generating types
//import "@typechain/viem";              // <-- viem target

const config: HardhatUserConfig = {
  solidity: "0.8.24",
};

export default config;
