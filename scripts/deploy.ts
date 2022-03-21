// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy

  const DripToken = await ethers.getContractFactory("DripToken");
  const dripToken = await DripToken.deploy(1000000);
  await dripToken.deployed();
  console.log("drip: ", dripToken.address);

  const Vault = await ethers.getContractFactory("Vault");
  const vault = await Vault.deploy(dripToken.address);
  await vault.deployed();
  console.log("vault: ", vault.address);

  await dripToken.setVaultAddress(vault.address);
  await dripToken.excludeAccount(vault.address);

  const [owner] = await ethers.getSigners();
  const Faucet = await ethers.getContractFactory("FaucetV4");
  const faucet = await Faucet.deploy(
    dripToken.address,
    vault.address,
    owner.address
  );
  await faucet.deployed();
  console.log("faucet: ", faucet.address);
  await faucet.updatePayoutRate(1);
  await faucet.updateMaxPayoutCap(parseEther("10000000000"));
  await dripToken.addAddressToWhitelist(faucet.address);
  await vault.addAddressToWhitelist(faucet.address);
  await dripToken.excludeAccount(faucet.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
