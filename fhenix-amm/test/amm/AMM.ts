import { createFheInstance } from "../../utils/instance";
import type { Signers } from "../types";
import { shouldBehaveLikeAMM } from "./AMM.behavior";
import { deployTwoETokenFixture } from "../etoken/EToken.fixture";
import { deployAMMFixture, getTokensFromFaucet } from "./AMM.fixture";
import hre from "hardhat";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    // get tokens from faucet if we're on localfhenix and don't have a balance
    // get tokens for first 2 accounts by default
    await getTokensFromFaucet();

    const { etoken0, etokenAddress0, etoken1, etokenAddress1 } = await deployTwoETokenFixture();

    this.etoken0 = etoken0;
    this.etoken1 = etoken1;

    this.etoken0Instance = await createFheInstance(hre, etokenAddress0);
    this.etoken1Instance = await createFheInstance(hre, etokenAddress1);

    // deploy test contract
    const { amm, ammAddress } = await deployAMMFixture(etokenAddress0, etokenAddress1);
    this.amm = amm;
    this.ammAddress = ammAddress;

    // initiate fhenixjs with amm
    this.ammInstance = await createFheInstance(hre, ammAddress);

    // set admin account/signer
    const signers = await hre.ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.user1 = signers[1];

    const eAmount = await this.ammInstance.instance.encrypt_uint8(
      100,
    );

    // mint, wrap and approve '1M' token0 to 2 users for tests
    await this.etoken0.connect(this.signers.admin).mint(this.signers.admin.address, 100);  
    await this.etoken0.connect(this.signers.user1).mint(this.signers.user1.address, 100);  
    await this.etoken0.connect(this.signers.admin).wrap(100);
    await this.etoken0.connect(this.signers.user1).wrap(100);
    await this.etoken0.connect(this.signers.admin).approveEncrypted(ammAddress, eAmount);
    await this.etoken0.connect(this.signers.user1).approveEncrypted(ammAddress, eAmount);

    // mint, wrap and approve '1M' token1 to 2 users for tests
    await this.etoken1.connect(this.signers.admin).mint(this.signers.admin.address, 100);  
    await this.etoken1.connect(this.signers.user1).mint(this.signers.user1.address, 100);  
    await this.etoken1.connect(this.signers.admin).wrap(100);
    await this.etoken1.connect(this.signers.user1).wrap(100);
    await this.etoken1.connect(this.signers.admin).approveEncrypted(ammAddress, eAmount);
    await this.etoken1.connect(this.signers.user1).approveEncrypted(ammAddress, eAmount);
  });

  describe("AMM", function () {
    shouldBehaveLikeAMM();
  }).timeout(1000000);
}).timeout(1000000);
