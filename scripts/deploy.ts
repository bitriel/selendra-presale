import { upgrades, ethers } from "hardhat";

async function main() {
  const PrivateSale = await ethers.getContractFactory("PrivateSaleSEL");
  const instance = await upgrades.deployProxy(PrivateSale, { kind: 'uups' });
  await instance.deployed();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });