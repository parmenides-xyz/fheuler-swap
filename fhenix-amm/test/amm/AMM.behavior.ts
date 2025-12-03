import { expect } from "chai";
import { EncryptionTypes } from "fhenixjs";
import hre from "hardhat";

export function shouldBehaveLikeAMM(): void {
  it("should allow user to add liquidity", async function () {
    //max supply amount is sqrt(255) = 15 rounded down
    //since using 8 bit euint
    const supplyAmount = 15;

      const esupplyAmount = await this.ammInstance.instance.encrypt_uint8(
        supplyAmount,
      );
  
      const eAdminBalanceToken0Before = await this.etoken0.balanceOfEncrypted(this.signers.admin.address, this.etoken0Instance.permission);
      const eAdminBalanceToken1Before = await this.etoken1.balanceOfEncrypted(this.signers.admin.address, this.etoken1Instance.permission);


      const adminBalanceToken0Before = this.etoken0Instance.instance.unseal(
        await this.etoken0.getAddress(),
        eAdminBalanceToken0Before,
      );

      const adminBalanceToken1Before = this.etoken1Instance.instance.unseal(
        await this.etoken1.getAddress(),
        eAdminBalanceToken1Before,
      );
  
      await this.amm.connect(this.signers.admin).addLiquidity(esupplyAmount, esupplyAmount);
  
      const eAdminBalanceToken0After = await this.etoken0.balanceOfEncrypted(this.signers.admin.address, this.etoken0Instance.permission);
      const eAdminBalanceToken1After = await this.etoken1.balanceOfEncrypted(this.signers.admin.address, this.etoken1Instance.permission);

      const adminBalanceToken0After = this.etoken0Instance.instance.unseal(
        await this.etoken0.getAddress(),
        eAdminBalanceToken0After,
      );

      const adminBalanceToken1After = this.etoken1Instance.instance.unseal(
        await this.etoken1.getAddress(),
        eAdminBalanceToken1After,
      );

      expect(Number(adminBalanceToken0Before) - supplyAmount).to.equal(Number(adminBalanceToken0After));
      expect(Number(adminBalanceToken1Before) - supplyAmount).to.equal(Number(adminBalanceToken1After));
  });
  it("should allow user to swap token 0 for token 1", async function () {
    const token0SellAmount = 3;

    const eToken0SellAmount = await this.ammInstance.instance.encrypt_uint8(
      token0SellAmount,
    );

    await this.amm.connect(this.signers.user1).swap(true, eToken0SellAmount);
  });
  it("should allow user to swap token 1 for token 0", async function () {
    const token1SellAmount = 3;

    const eToken1SellAmount = await this.ammInstance.instance.encrypt_uint8(
      token1SellAmount,
    );

    await this.amm.connect(this.signers.user1).swap(false, eToken1SellAmount);
  });
}
