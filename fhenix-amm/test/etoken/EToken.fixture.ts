import type { Counter, EToken, MyFHERC20 } from "../../types";
import axios from "axios";
import hre from "hardhat";

export async function deployETokenFixture(): Promise<{
  etoken: EToken;
  etokenAddress: string;
}> {
  const accounts = await hre.ethers.getSigners();
  const contractOwner = accounts[0];

  const EToken = await hre.ethers.getContractFactory("EToken");
  const etoken = await EToken.connect(contractOwner).deploy("EToken", "ETK");

  await etoken.waitForDeployment();
  const etokenAddress = await etoken.getAddress();

  return { etoken, etokenAddress };
}

export async function deployTwoETokenFixture(): Promise<{
  etoken0: MyFHERC20;
  etokenAddress0: string;
  etoken1: MyFHERC20;
  etokenAddress1: string;
}> {
  const accounts = await hre.ethers.getSigners();
  const contractOwner = accounts[0];

  const EToken0 = await hre.ethers.getContractFactory("MyFHERC20");
  const etoken0 = await EToken0.connect(contractOwner).deploy("EToken0", "ETK0");

  await etoken0.waitForDeployment();
  const etokenAddress0 = await etoken0.getAddress();

  const EToken1 = await hre.ethers.getContractFactory("MyFHERC20");
  const etoken1 = await EToken1.connect(contractOwner).deploy("EToken1", "ETK1");

  await etoken1.waitForDeployment();
  const etokenAddress1 = await etoken1.getAddress();

  return { etoken0, etokenAddress0, etoken1, etokenAddress1 };
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
