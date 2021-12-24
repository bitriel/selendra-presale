import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const deploy: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('PrivateSaleSEL', {
    from: deployer,
    log: true,
    deterministicDeployment: false
  })
}

deploy.tags = ['PrivateSaleSEL']
export default deploy