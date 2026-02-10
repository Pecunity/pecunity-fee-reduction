import { ContractTransaction } from 'ethers'
import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

import { createLogger } from '@layerzerolabs/io-devtools'
import { endpointIdToNetwork } from '@layerzerolabs/lz-definitions'

// Import LayerZero logging utilities
const logger = createLogger()

// Known error types for consistent error handling
enum KnownErrors {
    ERROR_GETTING_DEPLOYMENT = 'ERROR_GETTING_DEPLOYMENT',
    ERROR_QUOTING_GAS_COST = 'ERROR_QUOTING_GAS_COST',
    ERROR_SENDING_TRANSACTION = 'ERROR_SENDING_TRANSACTION',
}

// Known output types for consistent success messaging
enum KnownOutputs {
    SENT_VIA_OAPP = 'SENT_VIA_OAPP',
    TX_HASH = 'TX_HASH',
    EXPLORER_LINK = 'EXPLORER_LINK',
}

// Simple DebugLogger implementation for structured messaging
class DebugLogger {
    static printErrorAndFixSuggestion(errorType: KnownErrors, context: string) {
        logger.error(`❌ ${errorType}: ${context}`)
    }

    static printLayerZeroOutput(outputType: KnownOutputs, message: string) {
        logger.info(`✅ ${outputType}: ${message}`)
    }
}

// Get LayerZero scan link
function getLayerZeroScanLink(txHash: string, isTestnet = false): string {
    const baseUrl = isTestnet ? 'https://testnet.layerzeroscan.com' : 'https://layerzeroscan.com'
    return `${baseUrl}/tx/${txHash}`
}

// Get block explorer link (simplified version)
async function getBlockExplorerLink(networkName: string, txHash: string): Promise<string | undefined> {
    // This is a simplified version - in production you'd fetch from the metadata API
    const explorers: Record<string, string> = {
        'optimism-sepolia': 'https://sepolia-optimism.etherscan.io',
        'arbitrum-sepolia': 'https://sepolia.arbiscan.io',
        'avalanche-testnet': 'https://testnet.snowtrace.io',
    }

    const explorer = explorers[networkName]
    return explorer ? `${explorer}/tx/${txHash}` : undefined
}

task('lz:oapp:deactivate-token', 'Deactivates a token on the destination chain')
    .addOptionalParam('options', 'Execution options (hex string)', '0x', types.string)
    .setAction(async (args: { tokenid: string; options?: string }, hre: HardhatRuntimeEnvironment) => {
        logger.info(`Initiating token activation from ${hre.network.name}`)

        // Get the signer
        const [signer] = await hre.ethers.getSigners()
        logger.info(`Using signer: ${signer.address}`)

        // Get the deployed ActivationRouter contract
        let strategyBuilderFeeReductionContract
        let contractAddress: string
        try {
            const activationManagerDeployment = await hre.deployments.get('StrategyBuilderFeeReduction')
            contractAddress = activationManagerDeployment.address
            strategyBuilderFeeReductionContract = await hre.ethers.getContractAt(
                'StrategyBuilderFeeReduction',
                contractAddress,
                signer
            )
            logger.info(`StrategyBuilderFeeReduction contract found at: ${contractAddress}`)
        } catch (error) {
            DebugLogger.printErrorAndFixSuggestion(
                KnownErrors.ERROR_GETTING_DEPLOYMENT,
                `Failed to get StrategyBuilderFeeReduction deployment on network: ${hre.network.name}`
            )
            throw error
        }

        // Prepare options (convert hex string to bytes if provided)
        const options = args.options || '0x'
        logger.info(`Execution options: ${options}`)

        const feeReductionTx = await strategyBuilderFeeReductionContract.userTokenInfos(signer.address)

        logger.info(`Following token is activated: ${feeReductionTx.tokenId}`)

        logger.info('Token deactivation transaction...')
        let tx: ContractTransaction
        try {
            tx = await strategyBuilderFeeReductionContract.withdrawToken(700_000)
            logger.info(`  Transaction hash: ${tx.hash}`)
        } catch (error) {
            DebugLogger.printErrorAndFixSuggestion(
                KnownErrors.ERROR_SENDING_TRANSACTION,
                `For token ID: ${feeReductionTx.tokenId}, Contract: ${contractAddress}`
            )
            throw error
        }

        // 3️⃣ Wait for confirmation
        logger.info('Waiting for transaction confirmation...')
        const receipt = await tx.wait()
        logger.info(`  Gas used: ${receipt.gasUsed.toString()}`)
        logger.info(`  Block number: ${receipt.blockNumber}`)

        // 4️⃣ Success messaging and links
        DebugLogger.printLayerZeroOutput(
            KnownOutputs.SENT_VIA_OAPP,
            `Successfully activated token ${args.tokenid} on ${hre.network.name}`
        )

        // Get and display block explorer link
        const explorerLink = await getBlockExplorerLink(hre.network.name, receipt.transactionHash)
        if (explorerLink) {
            DebugLogger.printLayerZeroOutput(
                KnownOutputs.TX_HASH,
                `Block explorer link for source chain ${hre.network.name}: ${explorerLink}`
            )
        }

        // Get and display LayerZero scan link
        const scanLink = getLayerZeroScanLink(receipt.transactionHash, hre.network.name === 'arb-sepolia')
        DebugLogger.printLayerZeroOutput(
            KnownOutputs.EXPLORER_LINK,
            `LayerZero Scan link for tracking cross-chain delivery: ${scanLink}`
        )

        return {
            txHash: receipt.transactionHash,
            blockNumber: receipt.blockNumber,
            gasUsed: receipt.gasUsed.toString(),
            scanLink: scanLink,
            explorerLink: explorerLink,
        }
    })
