import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { SelendraSale } from "../types"

type ArgsType = {
  priceFeed: string;
  minInvestment: number,
  maxInvestment: number,
  supportedTokens: TokenArgs[];
}

type TokenArgs = {
  tokenAddress: string;
  priceFeed: string;
}

const ARGS: {[chainId: string]: ArgsType} = {
  "56": {
    priceFeed: "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE", // BNB/USD
    minInvestment: 10,
    maxInvestment: 100,
    supportedTokens: [
      {
        tokenAddress: "0xe9e7cea3dedca5984780bafc599bd69add087d56", // BUSD
        priceFeed: "0xcBb98864Ef56E9042e7d2efef76141f15731B82f" // BUSD/USD
      },
      {
        tokenAddress: "0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3", // DAI
        priceFeed: "0x132d3C0B1D2cEa0BC552588063bdBb210FDeecfA" // DAI/USD
      },
      {
        tokenAddress: "0x55d398326f99059fF775485246999027B3197955", // USDT
        priceFeed: "0xB97Ad0E74fa7d920791E90258A6E2085088b4320" // USDT/USD
      },
      {
        tokenAddress: "0x2170ed0880ac9a755fd29b2688956bd959f933f8", // ETH
        priceFeed: "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e" // ETH/USD
      }
    ]
  },
  "97": {
    priceFeed: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526", // BNB/USD
    minInvestment: 1,
    maxInvestment: 10,
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

    await deploy('SelendraSale', {
      from: deployer,
      args: [
        args.priceFeed,
        args.minInvestment,
        args.maxInvestment,
        "1650016800",
        3600,
        200,
        50,
        2
      ],
      log: true,
      deterministicDeployment: false
    })
    console.log("\n========= The Deployment has been successfully ============\n")

    const sale = await ethers.getContract("SelendraSale") as SelendraSale

    if(args.supportedTokens) {
      for(let i=0; i<args.supportedTokens.length; i++) {
        console.log("========= Setting Supported Token ============")
        console.log(`========= Token Address: ${args.supportedTokens[i].tokenAddress} ============`)
        console.log(`========= Price Feed Address: ${args.supportedTokens[i].priceFeed} ============\n`)
        await sale.setSupportedToken(args.supportedTokens[i].tokenAddress, args.supportedTokens[i].priceFeed).then(tx => tx.wait())
      }
    }
  }
}

deploy.tags = ['SelendraSale']
export default deploy