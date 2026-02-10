// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import 'dotenv/config'

import 'hardhat-deploy'
import '@nomicfoundation/hardhat-verify'

import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
import '@layerzerolabs/toolbox-hardhat'

import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'

import { EndpointId } from '@layerzerolabs/lz-definitions'

import './tasks/sendString'
import './tasks/fund-contract'
import './tasks/mint-token'
import './tasks/activate-token'
import './tasks/deactivate-token'
import { vars } from 'hardhat/config'

const ALCHEMY_API_KEY = vars.get('ALCHEMY_API_KEY')

function alchemyUrl(network: string) {
    return `https://${network}.g.alchemy.com/v2/${ALCHEMY_API_KEY}`
}

function getNetwork(network: string) {
    return {
        url: alchemyUrl(network),
        accounts: [PRIVATE_KEY],
    }
}

// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
const MNEMONIC = process.env.MNEMONIC

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = vars.get('PRIVATE_KEY')

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
      ? [PRIVATE_KEY]
      : undefined

if (accounts == null) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

const ETHERSCAN_API_KEY = vars.get('ETHERSCAN_API_KEY')

const config: HardhatUserConfig = {
    paths: {
        cache: 'cache/hardhat',
    },
    solidity: {
        compilers: [
            {
                version: '0.8.22',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        'arb-mainnet': {
            eid: EndpointId.ARBITRUM_V2_MAINNET,
            ...getNetwork('arb-mainnet'),
        },
        'bnb-mainnet': {
            eid: EndpointId.BSC_V2_MAINNET,
            url: 'https://public-bsc.nownodes.io',
            accounts,
        },
        'arb-sepolia': {
            eid: EndpointId.ARBSEP_V2_TESTNET,
            ...getNetwork('arb-sepolia'),
        },
        'bnb-testnet': {
            eid: EndpointId.BSC_V2_TESTNET,
            ...getNetwork('bnb-testnet'),
        },
        hardhat: {
            // Need this for testing because TestHelperOz5.sol is exceeding the compiled contract size limit
            allowUnlimitedContractSize: true,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0, // wallet address of index[0], of the mnemonic in .env
        },
    },
    verify: {
        etherscan: {
            apiKey: ETHERSCAN_API_KEY,
        },
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY,
    },
}

export default config
