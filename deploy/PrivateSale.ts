import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const deploy: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts, getChainId, ethers } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  const chainId = await getChainId()

  if(chainId == "97") {
    await deploy('PrivateSale', {
      from: deployer,
      args: [
        "0xDED2DEDf0cF48033cb50a4EF3e7587bAbc227151",
      ],
      log: true,
      deterministicDeployment: false
    })
  }
}

deploy.tags = ['PrivateSale']
export default deploy