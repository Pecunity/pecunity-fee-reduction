import assert from 'assert'
import { deployConfig } from '../hardhat.deploy.config'
import { type DeployFunction } from 'hardhat-deploy/types'
import { verify } from '../utils/verify'

// TODO declare your contract name here
const contractName = 'ActivationManager'

const router = 'ActivationRouter'

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
            `ActivationManager configuration didn't found on ${network} deployment, skipping ActivationManager deployment`
        )
        return
    }

    const { destId, tokenAddress } = _deployConfig

    let nonce = await hre.ethers.provider.getTransactionCount(deployer)

    let predictedAddress = hre.ethers.utils.getContractAddress({
        from: deployer,
        nonce: nonce + 1,
    })

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

    const { address } = await deploy(contractName, {
        from: deployer,
        args: [
            deployer,
            tokenAddress, // locking address
            predictedAddress, // predicted router address
        ],
        log: true,
        skipIfAlreadyDeployed: true,
    })

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)

    // Deploy router
    const routerDeployment = await deploy(router, {
        from: deployer,
        args: [
            endpointV2Deployment.address, // LayerZero's EndpointV2 address
            deployer, // owner
            address, // deployed activation manager
            destId, // destination id
        ],
        log: true,
        skipIfAlreadyDeployed: true,
    })

    console.log(`Deployed contract: ${router}, network: ${hre.network.name}, address: ${routerDeployment.address}`)

    await verify(routerDeployment.address, [
        endpointV2Deployment.address, // LayerZero's EndpointV2 address
        deployer, // owner
        address, // deployed activation manager
        destId, // destination id
    ])

    await verify(address, [
        deployer, // owner
        tokenAddress, // locking address
        predictedAddress, // predicted router address
    ])
}

deploy.tags = [contractName]

export default deploy
