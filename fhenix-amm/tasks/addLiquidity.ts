import { AMM } from "../types";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

task("task:addLiquidity")
  .addParam("amount", "Amount of tokens add to the AMM liquidity pool", "5")
  .setAction(async function (taskArguments: TaskArguments, hre) {
    const { fhenixjs, ethers, deployments } = hre;
    const [signer] = await ethers.getSigners();

    if ((await ethers.provider.getBalance(signer.address)).toString() === "0") {
      await fhenixjs.getFunds(signer.address);
    }

    const amountToAdd = Number(taskArguments.amount);
    const Amm = await deployments.get("AMM");

    console.log(
      `Running addLiquidity(${amountToAdd}), targeting contract at: ${Amm.address}`,
    );

    const contract = await ethers.getContractAt("AMM", Amm.address);

    const encryptedAmount = await fhenixjs.encrypt_uint8(amountToAdd);

    let contractWithSigner = contract.connect(signer) as unknown as AMM;

    try {
      // add() gets `bytes calldata encryptedValue`
      // therefore we need to pass in the `data` property
      await contractWithSigner.addLiquidity(encryptedAmount, encryptedAmount);
    } catch (e) {
      console.log(`Failed to send add liquidity transaction: ${e}`);
      return;
    }
  });
