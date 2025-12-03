import { AMM } from "../types";
import { task } from "hardhat/config";
import { boolean } from "hardhat/internal/core/params/argumentTypes";
import type { TaskArguments } from "hardhat/types";

task("task:swap")
  .addParam("amount", "Amount of tokens to swap", "5")
  .addParam("zeroforone", "swap token 0 for token 1 (true) or vice versa (false)", "true")
  .setAction(async function (taskArguments: TaskArguments, hre) {
    const { fhenixjs, ethers, deployments } = hre;
    const [signer] = await ethers.getSigners();

    if ((await ethers.provider.getBalance(signer.address)).toString() === "0") {
      await fhenixjs.getFunds(signer.address);
    }

    const amountToSwap = Number(taskArguments.amount);
    const zeroForOne = Boolean(taskArguments.zeroForOne);

    const Amm = await deployments.get("AMM");

    console.log(
      `Running swap(${zeroForOne},${amountToSwap}), targeting contract at: ${Amm.address}`,
    );

    const contract = await ethers.getContractAt("AMM", Amm.address);

    const encryptedAmount = await fhenixjs.encrypt_uint8(amountToSwap);

    let contractWithSigner = contract.connect(signer) as unknown as AMM;

    try {
      // add() gets `bytes calldata encryptedValue`
      // therefore we need to pass in the `data` property
      await contractWithSigner.swap(zeroForOne, encryptedAmount);
    } catch (e) {
      console.log(`Failed to send swap transaction: ${e}`);
      return;
    }
  });
