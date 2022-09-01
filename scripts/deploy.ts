// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers, upgrades } from "hardhat";

async function main() {
  const [owner] = await ethers.getSigners();
  console.log("Deploying contracts with the account: ", owner.address);

  console.log("Account balance: ", (await owner.getBalance()).toString());

  /* ==================================================================== */
  console.log("=== HORDE deploy START");
  const hordeToken = await ethers.getContractFactory("HORDEToken");
  const hordeTokenContract = await upgrades.deployProxy(hordeToken, []);
  await hordeTokenContract.deployed();
  console.log("Horde address = ", hordeTokenContract.address);

  // console.log("=== HORDE deploy START")
  // const hordeToken = await ethers.getContractFactory("HORDEToken");
  // const hordeTokenContract = await upgrades.upgradeProxy(
  //   "0x",
  //   hordeToken
  // )
  // await hordeTokenContract.deployed()
  // console.log("Horde address = ", hordeTokenContract.address)

  /* ==================================================================== */
  console.log("=== Liquidity Manager deploy START");
  const lpManager = await ethers.getContractFactory("LiquidityManager");
  const lpManagerContract = await upgrades.deployProxy(lpManager, []);
  await lpManagerContract.deployed();
  console.log("lpManager address = ", lpManagerContract.address);

  // console.log("=== Liquidity Manager deploy START")
  // const lpManager = await ethers.getContractFactory("LiquidityManager");
  // const lpManagerContract = await upgrades.upgradeProxy(
  //   "0x",
  //   lpManager
  // )
  // await lpManagerContract.deployed()
  // console.log("lpManager address = ", lpManagerContract.address)

  /* ==================================================================== */
  console.log("=== Node Manager deploy START");
  const nodeManager = await ethers.getContractFactory("NodeManager");
  const nodeManagerContract = await upgrades.deployProxy(nodeManager, []);
  await nodeManagerContract.deployed();
  console.log("nodeManager address = ", nodeManagerContract.address);

  // console.log("=== Node Manager deploy START")
  // const nodeManager = await ethers.getContractFactory("NodeManager");
  // const nodeManagerContract = await upgrades.upgradeProxy(
  //   "0x",
  //   nodeManager
  // )
  // await nodeManagerContract.deployed()
  // console.log("nodeManager address = ", nodeManagerContract.address)

  /* ==================================================================== */
  const hordeChurchFactory = await ethers.getContractFactory("HordeChurch");
  const hordeChurchContract = await hordeChurchFactory.deploy("");
  await hordeChurchContract.deployed();
  console.log("HordeChurchContract deployed to: ", hordeChurchContract.address);

  /* ==================================================================== */
  const hordeRescueFactory = await ethers.getContractFactory("HordeRescue");
  const hordeRescueContract = await hordeRescueFactory.deploy("");
  await hordeRescueContract.deployed();
  console.log("HordeRescueContract deployed to: ", hordeRescueContract.address);

  /* ==================================================================== */
  const hordeWastelandFactory = await ethers.getContractFactory(
    "HordeWasteland"
  );
  const hordeWastelandContract = await hordeWastelandFactory.deploy("");
  await hordeWastelandContract.deployed();
  console.log(
    "HordeWastelandContract deployed to: ",
    hordeWastelandContract.address
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
