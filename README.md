# Selendra Pre-IDO Contracts

The project comes with a presale contract and a private sale contract, ready-for-deploy scripts that deploys those contracts,

Try running some of the following tasks:

first of all, we need to install all needed-dev dependencies through this command:

```shell
yarn install
```

next, create an **.env** file in the root of project, same keys as **.env.example** and set those values depend on your needs.
then, compile both contracts to see if no errors, and the size of those contracts:

```shell
yarn compile
```

run coverage to check more in deep:

```shell
yarn coverage
```

testing

```shell
yarn test
```

if no errors on testing, we're good to go to deployments with options(network, tags, reset):

```shell
npx hardhat deploy --reset --network bsc-testnet --tags Presale                                
```

run cleaning with hardhat to clean the build folders and cache file:

```shell
yarn clean                             
```

generate docs with hardhat-docgen for static site:

```shell
yarn docs                             
```

# Etherscan verification

To try out Etherscan verification, you first need to deploy a contract to an Ethereum network that's supported by Etherscan, such as Ropsten.

In this project, copy the .env.template file to a file named .env, and then edit it to fill in the details. Enter your Etherscan API key, your Ropsten node URL (eg from Alchemy), and the private key of the account which will send the deployment transaction. With a valid .env file in place, after you deployed your contract, Then, copy the etherscan API key and paste it in to replace `ETHERSCAN_API_KEY` in this command. This will verify both contracts if those are not verified yet:

```shell
npx hardhat --network bsc-testnet etherscan-verify --api-key ETHERSCAN_API_KEY
```
