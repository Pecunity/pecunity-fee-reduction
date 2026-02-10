import assert from 'assert'
import { deployConfig } from '../hardhat.deploy.config'
import { type DeployFunction } from 'hardhat-deploy/types'
import { verify } from '../utils/verify'

// TODO declare your contract name here
const contractName = 'StrategyBuilderFeeReduction'

const router = 'StrategyBuilderFeeReductionRouter'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    const network = hre.network.name as string

    const _deployConfig = deployConfig[network][contractName]

    if (!_deployConfig) {
        console.warn(
            `StrategyBuilderFeeReduction configuration didn't found on ${network} deployment, skipping StrategyBuilderFeeReduction deployment`
        )
        return
    }

    const { destId, lockingAddress } = _deployConfig

    let nonce = await hre.ethers.provider.getTransactionCount(deployer)

    let predictedAddress = hre.ethers.utils.getContractAddress({
        from: deployer,
        nonce: nonce + 1,
    })

    console.log(`Predicted address: ${predictedAddress}`)
    console.log(`Locking address: ${lockingAddress}`)

    // This is an external deployment pulled in from @layerzerolabs/lz-evm-sdk-v2
    //
    // @layerzerolabs/toolbox-hardhat takes care of plugging in the external deployments
    // from @layerzerolabs packages based on the configuration in your hardhat config
    //
    // For this to work correctly, your network config must define an eid property
    // set to `EndpointId` as defined in @layerzerolabs/lz-definitions
    //
    // For example:
    //
    // networks: {
    //   fuji: {
    //     ...
    //     eid: EndpointId.AVALANCHE_V2_TESTNET
    //   }
    // }
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')

    console.log(`EndpointV2 address: ${endpointV2Deployment.address}`)

    const deployment = await deploy(contractName, {
        from: deployer,
        args: [
            lockingAddress, // locking address
            predictedAddress, // predicted router address
        ],
        log: false,
    })

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${deployment.address}`)

    // Deploy router
    const routerDeployment = await deploy(router, {
        from: deployer,
        args: [
            endpointV2Deployment.address, // LayerZero's EndpointV2 address
            deployer, // owner
            deployment.address, // deployed strategy fee reduction
            destId, // destination id
        ],
        log: true,
        skipIfAlreadyDeployed: true,
    })

    console.log(`Deployed contract: ${router}, network: ${hre.network.name}, address: ${routerDeployment.address}`)

    await verify(routerDeployment.address, [
        endpointV2Deployment.address, // LayerZero's EndpointV2 address
        deployer, // owner
        deployment.address, // deployed strategy fee reduction
        destId, // destination id
    ])

    await verify(deployment.address, [
        lockingAddress, // locking address
        predictedAddress, // predicted router address
    ])
}

deploy.tags = [contractName]

export default deploy
