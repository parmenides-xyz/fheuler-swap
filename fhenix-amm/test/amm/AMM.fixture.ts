import type { AMM } from "../../types";
import axios from "axios";
import hre from "hardhat";
import { Address } from "hardhat-deploy/types";

export async function deployAMMFixture(token0: Address, token1: Address): Promise<{
  amm: AMM;
  ammAddress: string;
}> {
  const accounts = await hre.ethers.getSigners();
  const contractOwner = accounts[0];

  const AMM = await hre.ethers.getContractFactory("AMM");
  const amm = await AMM.connect(contractOwner).deploy(token0, token1);

  await amm.waitForDeployment();
  const ammAddress = await amm.getAddress();

  return { amm, ammAddress };
}

export async function getTokensFromFaucet(numSigners: number = 2) {
  if (hre.network.name === "localfhenix") {
    const signers = await hre.ethers.getSigners();

    for(let i = 0; i < numSigners; i++){
      if ((await hre.ethers.provider.getBalance(signers[i].address)).toString() === "0") {
        await hre.fhenixjs.getFunds(signers[i].address);
      }
    }
  }
}
