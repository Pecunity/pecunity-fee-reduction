export const deployConfig: Record<string, any> = {
    'arb-mainnet': {
        ActivationManager: {
            destId: 30102,
            tokenAddress: '0x413c2834f02003752d6Cc0Bcd1cE85Af04D62fBE',
        },
    },
    // 'arb-sepolia': {
    //     ActivationManager: {
    //         destId: 40102,
    //         tokenAddress: '0xf3550B501caf1b5C11b02132FA7490072F758820',
    //     },
    // },
    'bnb-mainnet': {
        StrategyBuilderFeeReduction: {
            destId: 30110,
            lockingAddress: '0x75B9a6759bF03Deed169792c86111Dd7037f97EB',
            factory: '0xc245f625b416F8Da96dD0Bfc3d190cd9FeC262A3',
        },
    },
    // 'bnb-testnet': {
    //     StrategyBuilderFeeReduction: {
    //         destId: 40231,
    //         lockingAddress: '0x63Cdf4c4fF8091229E1088eDDB36DA1BB3Cfe5B5',
    //     },
    // },
}
