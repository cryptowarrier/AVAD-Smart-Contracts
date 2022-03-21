import { expect } from "chai";
import { parseEther, formatEther } from "ethers/lib/utils";
import { ethers, network } from "hardhat";

describe("faucet", function () {
  it("faucet stake, claim", async function () {
    const [owner, account] = await ethers.getSigners();
    const DripToken = await ethers.getContractFactory("DripToken");
    const dripToken = await DripToken.deploy(1000000);
    await dripToken.deployed();

    const Vault = await ethers.getContractFactory("Vault");
    const vault = await Vault.deploy(dripToken.address);
    await vault.deployed();

    await dripToken.setVaultAddress(vault.address);
    await dripToken.excludeAccount(vault.address);
    


    const Faucet = await ethers.getContractFactory("FaucetV4");
    const faucet = await Faucet.deploy(
      dripToken.address,
      vault.address,
      owner.address
    );
    await faucet.deployed();
    await dripToken.addAddressToWhitelist(faucet.address);
    await dripToken.excludeAccount(faucet.address);
    await faucet.setMinAmount(parseEther("10"));
    // deposit
    
    const approveTx = await dripToken.approve(faucet.address, parseEther("100"));
    await approveTx.wait();

    await faucet.updatePayoutRate(1);
    await faucet.updateMaxPayoutCap(parseEther("10000000000"));
    await vault.addAddressToWhitelist(faucet.address);


    const depoistTx = await faucet.deposit(parseEther("100"));
    await depoistTx.wait();
    
    await expect(faucet.claim()).to.be.revertedWith(
      "You can't calim befor 1 day!"
    );

    // increase time
    await network.provider.send("evm_increaseTime", [86400 * 1]); 
    await network.provider.send("evm_mine");
    
    let payouts = await faucet.payoutOf(owner.address);
    // console.log(formatEther(payouts[0]));
    const balance1 = await dripToken.balanceOf(owner.address);
    const claimTx = await faucet.claim();
    await claimTx.wait();
    const balance2 = await dripToken.balanceOf(owner.address);
    expect(balance2 > balance1).to.true;
    // calim for test
    await faucet.connect(account).claimForTest();
    const balance3 = await dripToken.balanceOf(account.address);
    expect(balance3).to.eq(parseEther("100"));
    // reverted duplicated claim
    await expect(faucet.connect(account).claimForTest()).to.revertedWith('You already claimed!');
  });
});
