import { DeployFunction } from "hardhat-deploy/types";
import { createFheInstance } from "../utils/instance";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chalk from "chalk";

const hre = require("hardhat");

const func: DeployFunction = async function () {
  const { fhenixjs, ethers } = hre;
  const { deploy } = hre.deployments;
  const [signer] = await ethers.getSigners();

  if ((await ethers.provider.getBalance(signer.address)).toString() === "0") {
    if (hre.network.name === "localfhenix") {
      await fhenixjs.getFunds(signer.address);
    } else {
        console.log(
            chalk.red("Please fund your account with testnet FHE from https://faucet.fhenix.zone"));
        return;
    }
  }

  const token0 = await deploy("MyFHERC20", {
    from: signer.address,
    args: ["EToken0", "ETK0"],
    log: true,
    skipIfAlreadyDeployed: false,
  });

  const token1 = await deploy("MyFHERC20", {
    from: signer.address,
    args: ["EToken1", "ETK1"],
    log: true,
    skipIfAlreadyDeployed: false,
  });

  const amm = await deploy("AMM", {
    from: signer.address,
    args: [token0.address, token1.address],
    log: true,
    skipIfAlreadyDeployed: false,
  });

  console.log(`Token0 contract: `, token0.address);
  console.log(`Token1 contract: `, token1.address);
  console.log(`AMM contract: `, amm.address);
};

export default func;
func.id = "deploy_amm";
func.tags = ["AMM"];
