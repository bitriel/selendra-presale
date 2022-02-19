import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

type ArgsType = {
  tokenAddress: string;
  priceFeed: string;
  minInvestment: number,
  maxInvestment: number
}

const ARGS: {[chainId: string]: ArgsType} = {
  "56": {
    tokenAddress: "0x55d398326f99059ff775485246999027b3197955", // USDT
    priceFeed: "0xb97ad0e74fa7d920791e90258a6e2085088b4320", // USDT/USD
    minInvestment: 10,
    maxInvestment: 100
  },
  "97": {
    tokenAddress: "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd", // USDT
    priceFeed: "0xEca2605f0BCF2BA5966372C99837b1F182d3D620", // USDT/USD
    minInvestment: 1,
    maxInvestment: 10,
  }
}

const deploy: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  const chainId = await getChainId()

  if(chainId in ARGS) {
    const args = ARGS[chainId]

    await deploy('SelendraSale', {
      from: deployer,
      args: [
        args.tokenAddress,
        args.priceFeed,
        args.minInvestment,
        args.maxInvestment,
        "1646253213"
      ],
      log: true,
      deterministicDeployment: false
    })
    console.log("\n========= The Deployment has been successfully ============\n")
  }
}

deploy.tags = ['SelendraSale']
export default deploy