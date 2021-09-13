import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { Presale } from "../types"

type ArgsType = {
  tokenAddress: string;
  priceFeed: string;
  supportedTokens?: ArgsType[];
}

const ARGS: {[chainId: string]: ArgsType} = {
  "97": {
    tokenAddress: "0xDED2DEDf0cF48033cb50a4EF3e7587bAbc227151", // KUM
    priceFeed: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526", // BNB/USD
    supportedTokens: [
      {
        tokenAddress: "0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee", // BUSD
        priceFeed: "0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa" // BUSD/USD
      },
      {
        tokenAddress: "0xEC5dCb5Dbf4B114C9d0F65BcCAb49EC54F6A0867", // DAI
        priceFeed: "0xE4eE17114774713d2De0eC0f035d4F7665fc025D" // DAI/USD
      },
      {
        tokenAddress: "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd", // USDT
        priceFeed: "0xEca2605f0BCF2BA5966372C99837b1F182d3D620" // USDT/USD
      },
      {
        tokenAddress: "0xd66c6b4f0be8ce5b39d52e0fd1344c389929b378", // ETH
        priceFeed: "0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7" // ETH/USD
      }
    ]
  }
}

const deploy: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts, getChainId, ethers } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  const chainId = await getChainId()

  if(chainId in ARGS) {
    const args = ARGS[chainId]

    await deploy('Presale', {
      from: deployer,
      args: [
        args.tokenAddress,
        args.priceFeed,
        "12320350",
        "12521950"
      ],
      log: true,
      deterministicDeployment: false
    })

    const presale = await ethers.getContract("Presale") as Presale
    if(args.supportedTokens) {
      await Promise.all(args.supportedTokens?.map(
        token => presale.setSupportedToken(token.tokenAddress, token.priceFeed)
      ))
    }
  }
}

deploy.tags = ['Presale']
export default deploy