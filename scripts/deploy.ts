import { ethers, upgrades } from "hardhat";
import { parseEther } from "ethers";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("🚀 Deploying contracts with:", deployer.address);

  // --- Deploy WRAMBLING Token ---
  const Wrambling = await ethers.getContractFactory("Wrambling");
  const wrambling = await Wrambling.deploy();
  await wrambling.waitForDeployment();
  const wramblingAddress = await wrambling.getAddress();
  console.log("🪙 Wrambling token deployed at:", wramblingAddress);

  // --- Deploy Janken (Upgradeable Proxy) ---
  const fee = parseEther("0.001"); // 0.001 ETH fee
  const Janken = await ethers.getContractFactory("Janken");
  const janken = await upgrades.deployProxy(Janken, [fee], {
    initializer: "initialize", // or remove if you use constructor
    kind: "uups", // or "transparent" if using TransparentUpgradeableProxy
  });
  await janken.waitForDeployment();
  const jankenAddress = await janken.getAddress();
  console.log("🎮 Janken proxy deployed at:", jankenAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
