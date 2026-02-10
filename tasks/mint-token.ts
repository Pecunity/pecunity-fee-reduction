import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

task('mint-token', 'Mint tokens for the StrategyBuilderFeeReduction contract').setAction(
    async (_args, hre: HardhatRuntimeEnvironment) => {
        const deployment = await hre.deployments.get('MockNFT')

        const tokenContract = await hre.ethers.getContractAt('MockNFT', deployment.address)

        const [signer] = await hre.ethers.getSigners()

        console.log('mint token to', signer.address)

        const trx = await tokenContract.mint(signer.address, 4)
        await trx.wait()

        console.log('mint token transaction', trx)
    }
)
