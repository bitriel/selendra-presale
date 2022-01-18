import { upgrades, ethers } from "hardhat";

async function main() {
  const proxyAddress = "0x0000";
  const PrivateSaleV2 = await ethers.getContractFactory("PrivateSaleSELV2");
  const upgraded = await upgrades.deployProxy(proxyAddress, PrivateSaleV2);
  await upgraded.deployed();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });