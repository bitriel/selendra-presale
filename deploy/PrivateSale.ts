import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const TOKEN_ADDRESS: {[chainId: string]: string} = {
  "56": "0x30bab6b88db781129c6a4e9b7926738e3314cf1c",
  "97": "0xDED2DEDf0cF48033cb50a4EF3e7587bAbc227151",
}

const deploy: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  const chainId = await getChainId()

  if(chainId in TOKEN_ADDRESS) {
    await deploy('PrivateSale', {
      from: deployer,
      args: [
        TOKEN_ADDRESS[chainId],
      ],
      log: true,
      deterministicDeployment: false
    })
  }
}

deploy.tags = ['PrivateSale']
export default deploy