import { createFheInstance } from "../../utils/instance";
import type { Signers } from "../types";
import { shouldBehaveLikeCounter } from "./EToken.behavior";
import { deployETokenFixture, getTokensFromFaucet } from "./EToken.fixture";
import hre from "hardhat";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    // get tokens from faucet if we're on localfhenix and don't have a balance
    // get tokens for first 2 accounts by default
    await getTokensFromFaucet();
    // deploy test contract
    const { etoken, etokenAddress } = await deployETokenFixture();
    this.etoken = etoken;

    // initiate fhenixjs
    this.instance = await createFheInstance(hre, etokenAddress);

    // set admin account/signer
    const signers = await hre.ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.user1 = signers[1];

    // mint '1M' tokens to 3 users for tests
    await this.etoken.connect(this.signers.admin).mint(this.signers.admin.address, 1_000_000);  
    await this.etoken.connect(this.signers.user1).mint(this.signers.user1.address, 1_000_000);  
  });

  describe("EToken", function () {
    //shouldBehaveLikeCounter();
  });
});
