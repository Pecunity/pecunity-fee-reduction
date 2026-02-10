import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { Contract, ContractFactory } from 'ethers'
import { deployments, ethers } from 'hardhat'
import { Options } from '@layerzerolabs/lz-v2-utilities'
import { parseEther } from 'ethers/lib/utils'
import { expect } from 'chai'
// import { expect } from 'chai'

const NATIVE_COIN_BALANCE = parseEther('0.1')

describe('FeeReduction Staging Test', function () {
    // Constant representing a mock Endpoint ID for testing purposes
    const eidA = 1
    const eidB = 2
    // Declaration of variables to be used in the test suite
    let ActivationManager: ContractFactory
    let ActivationRouter: ContractFactory
    let StrategyBuilderFeeReductionRouter: ContractFactory
    let StrategyBuilderFeeReduction: ContractFactory
    let MockNFT: ContractFactory
    let MockLocker: ContractFactory
    let EndpointV2Mock: ContractFactory

    let ownerA: SignerWithAddress
    let ownerB: SignerWithAddress
    let endpointOwner: SignerWithAddress
    let user: SignerWithAddress
    let badActor: SignerWithAddress

    let activationManagerA: Contract
    let activationRouter: Contract
    let strategyBuilderFeeReductionRouter: Contract
    let strategyBuilderFeeReduction: Contract
    let mockEndpointV2A: Contract
    let mockEndpointV2B: Contract
    let mockNFT: Contract
    let mockLocker: Contract

    // Before hook for setup that runs once before all tests in the block
    before(async function () {
        // Contract factory for our tested contract
        ActivationManager = await ethers.getContractFactory('ActivationManager')
        ActivationRouter = await ethers.getContractFactory('ActivationRouter')
        StrategyBuilderFeeReductionRouter = await ethers.getContractFactory('StrategyBuilderFeeReductionRouter')
        StrategyBuilderFeeReduction = await ethers.getContractFactory('StrategyBuilderFeeReduction')
        MockNFT = await ethers.getContractFactory('MockNFT')
        MockLocker = await ethers.getContractFactory('MockLocker')

        // Fetching the first three signers (accounts) from Hardhat's local Ethereum network
        const signers = await ethers.getSigners()

        ;[ownerA, ownerB, endpointOwner, user, badActor] = signers

        // The EndpointV2Mock contract comes from @layerzerolabs/test-devtools-evm-hardhat package
        // and its artifacts are connected as external artifacts to this project
        //
        // Unfortunately, hardhat itself does not yet provide a way of connecting external artifacts,
        // so we rely on hardhat-deploy to create a ContractFactory for EndpointV2Mock
        //
        // See https://github.com/NomicFoundation/hardhat/issues/1040
        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock')
        EndpointV2Mock = new ContractFactory(EndpointV2MockArtifact.abi, EndpointV2MockArtifact.bytecode, endpointOwner)
    })

    // beforeEach hook for setup that runs before each test in the block
    beforeEach(async function () {
        // Deploying a mock LZ EndpointV2 with the given Endpoint ID
        mockEndpointV2A = await EndpointV2Mock.deploy(eidA)
        mockEndpointV2B = await EndpointV2Mock.deploy(eidB)

        // Deploying a mock NFT contract
        mockNFT = await MockNFT.deploy()

        let nonce = await ownerA.getTransactionCount()

        // Predict next contract address
        let predictedAddress = ethers.utils.getContractAddress({
            from: ownerA.address,
            nonce: nonce + 1,
        })
        // Deploying two instances of MyOApp contract and linking them to the mock LZEndpoint
        activationManagerA = await ActivationManager.deploy(ownerA.address, mockNFT.address, predictedAddress)
        activationRouter = await ActivationRouter.deploy(
            mockEndpointV2A.address,
            ownerA.address,
            activationManagerA.address,
            eidB
        )

        // Deploying a mock locker contract
        mockLocker = await MockLocker.deploy()

        nonce = await ownerA.getTransactionCount()

        predictedAddress = ethers.utils.getContractAddress({
            from: ownerA.address,
            nonce: nonce + 1,
        })

        strategyBuilderFeeReduction = await StrategyBuilderFeeReduction.deploy(mockLocker.address, predictedAddress)

        strategyBuilderFeeReductionRouter = await StrategyBuilderFeeReductionRouter.deploy(
            mockEndpointV2B.address,
            ownerB.address,
            strategyBuilderFeeReduction.address,
            eidA
        )

        // Setting destination endpoints in the LZEndpoint mock for each TokenLocker instance
        await mockEndpointV2A.setDestLzEndpoint(strategyBuilderFeeReductionRouter.address, mockEndpointV2B.address)
        await mockEndpointV2B.setDestLzEndpoint(activationRouter.address, mockEndpointV2A.address)

        // Setting each ActivationManager instance as a peer of the other
        await activationRouter
            .connect(ownerA)
            .setPeer(eidB, ethers.utils.zeroPad(strategyBuilderFeeReductionRouter.address, 32))
        await strategyBuilderFeeReductionRouter
            .connect(ownerB)
            .setPeer(eidA, ethers.utils.zeroPad(activationRouter.address, 32))

        await ownerA.sendTransaction({ to: activationManagerA.address, value: NATIVE_COIN_BALANCE })
        await ownerB.sendTransaction({ to: strategyBuilderFeeReduction.address, value: NATIVE_COIN_BALANCE })

        const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()

        await activationRouter.connect(ownerA).setEnforcedOptions([
            {
                eid: eidA,
                options: options,
                msgType: 1,
            },
        ])
    })

    // A test case to verify message sending functionality
    it('should activate the token and transfer information to destination b', async function () {
        const tokenRarity = 4

        // mint nft for user
        await mockNFT.connect(user).mint(user.address, tokenRarity)

        await mockNFT.connect(user).approve(activationManagerA.address, 1)

        // activate token locker
        const trx = await activationManagerA.connect(user).activateToken(1, 200_000)

        await trx.wait()

        const newTokenOwner = await mockNFT.ownerOf(1)

        expect(newTokenOwner).to.be.equal(activationManagerA.address)

        const tokenInfoDestB = await strategyBuilderFeeReduction.userTokenInfos(user.address)

        expect(tokenInfoDestB.tokenId.toString()).to.be.equal(ethers.BigNumber.from(1).toString())

        expect(tokenInfoDestB.rarity.toString()).to.be.equal(ethers.BigNumber.from(tokenRarity).toString())

        const feeReduction = await strategyBuilderFeeReduction.getFeeReduction(user.address)

        expect(feeReduction.toString()).to.be.equal(ethers.BigNumber.from(5000).toString())
    })

    it('should deactivate and tranfer token back to user on destination A', async function () {
        // First activate token

        const tokenRarity = 4

        // mint nft for user
        await mockNFT.connect(user).mint(user.address, tokenRarity)

        await mockNFT.connect(user).approve(activationManagerA.address, 1)

        // activate token locker
        await activationManagerA.connect(user).activateToken(1, 200_000)

        // deactivate token from the fee reduction

        await strategyBuilderFeeReduction.connect(user).withdrawToken(200_000)

        const newTokenOwner = await mockNFT.ownerOf(1)

        expect(newTokenOwner).to.be.equal(user.address)

        const feeReduction = await strategyBuilderFeeReduction.getFeeReduction(user.address)

        expect(feeReduction.toString()).to.be.equal(ethers.BigNumber.from(0).toString())
    })

    it('should revert on destination B when the caller is not the router', async function () {
        try {
            await strategyBuilderFeeReduction.connect(badActor).activateTokenForUser(user.address, 1, 1)
            expect.fail('Expected revert')
        } catch (err: any) {
            expect(err.message).to.include('NotAllowed()')
        }
    })

    it('should revert on destination A when the caller ist not the router', async function () {
        try {
            await activationManagerA.connect(badActor).deactivateToken(user.address, 1)
            expect.fail('Expected revert')
        } catch (err: any) {
            expect(err.message).to.include('NotAllowed()')
        }
    })

    it('should revert on withdrawToken when the caller has no active token', async function () {
        try {
            await strategyBuilderFeeReduction.connect(badActor).withdrawToken(200_000)
            expect.fail('Expected revert')
        } catch (err: any) {
            expect(err.message).to.include('NoTokenActive()')
        }
    })

    it('should revert on activate when the caller is not the owner of the token', async function () {
        // mint nft for user
        await mockNFT.connect(user).mint(user.address, 3)

        try {
            await activationManagerA.connect(badActor).activateToken(1, 200_000)
            expect.fail('Expected revert')
        } catch (err: any) {
            expect(err.message).to.include('NotOwnerOfToken()')
        }
    })
})
