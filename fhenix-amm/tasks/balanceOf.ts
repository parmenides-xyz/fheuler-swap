import { AMM } from "../types";
import { createFheInstance } from "../utils/instance";
import { task } from "hardhat/config";
import { boolean } from "hardhat/internal/core/params/argumentTypes";
import type { TaskArguments } from "hardhat/types";

task("task:balanceOf")  
  .setAction(async function (taskArguments: TaskArguments, hre) {
    const { fhenixjs, ethers, deployments } = hre;
    const [signer] = await ethers.getSigners();

    if ((await ethers.provider.getBalance(signer.address)).toString() === "0") {
      await fhenixjs.getFunds(signer.address);
    }

    const token0Address = "0x3804398B131366AFcE8B1809f8e28F0DCA6A5947";
    const token1Address = "0x0f725F0BdE5f03212e6f80def2c0BA0128Cc451e";

    const token0Instance = await createFheInstance(hre, token0Address);
    const token1Instance = await createFheInstance(hre, token1Address);

    const token0Contract = await ethers.getContractAt("MyFHERC20", token0Address);
    const token1Contract = await ethers.getContractAt("MyFHERC20", token1Address);

    try {
      const eSignerToken0Balance = await token0Contract.balanceOfEncrypted(signer.address, token0Instance.permission);

      const signerToken0Balance = token0Instance.instance.unseal(
        token0Address,
        eSignerToken0Balance,
      );

      console.log(`Signer Token 0 Encrypted Balance ${signerToken0Balance}`);

      const eSignerToken1Balance = await token1Contract.balanceOfEncrypted(signer.address, token1Instance.permission);

      const signerToken1Balance = token1Instance.instance.unseal(
        token1Address,
        eSignerToken1Balance,
      );

      console.log(`Signer Token 1 Encrypted Balance ${signerToken1Balance}`);

    } catch (e) {
      console.log(`Failed to fetch balances: ${e}`);
      return;
    }
  });
