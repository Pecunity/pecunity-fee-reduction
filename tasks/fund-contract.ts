import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

task('fund-contract', 'Fund a contract with native tokens')
    .addParam('amount', 'The amount of native tokens to fund')
    .setAction(async (args, hre: HardhatRuntimeEnvironment) => {
        const amount = args.amount

        const contract = hre.network.name === 'arb-sepolia' ? 'ActivationManager' : 'StrategyBuilderFeeReduction'

        const deployment = await hre.deployments.get(contract)

        const [signer] = await hre.ethers.getSigners()

        const balanceBefore = await hre.ethers.provider.getBalance(deployment.address)
        console.log(`Balance before: ${hre.ethers.utils.formatEther(balanceBefore)}`)

        await signer.sendTransaction({
            to: deployment.address,
            value: hre.ethers.utils.parseEther(amount),
        })

        const balanceAfter = await hre.ethers.provider.getBalance(deployment.address)
        console.log(`Balance after: ${hre.ethers.utils.formatEther(balanceAfter)}`)
    })
