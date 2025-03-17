import { ethers } from 'hardhat';

export const ADDRESSES = {
    BASE: {
        OWNER: '0x9909ee4947be39c208607d8d2473d68c05cef8f9',
        WETH: '0x4200000000000000000000000000000000000006',
        USDC: '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913',
        AAVE_V3_POOL: '0xA238Dd80C259a72e81d7e4664a9801593F98d1c5',
        MORPHO: '0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb',
        ONE_INCH_ROUTER_V6: '0x111111125421cA6dc452d289314280a0f8842A65',
        MORHO_VAULTS: {
            USDC: {
                'steakhouse-usdc': '0xbeef010f9cb27031ad51e3333f9af9c6b1228183',
                'gauntlet-usdc-prime': '0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61',
                'gauntlet-usdc-core': '0xc0c5689e6f4D256E861F65465b691aeEcC0dEb12',
            },
            WETH: {
                'ionic-ecosystem-weth': '0x5A32099837D89E3a794a44fb131CBbAD41f87a8C',
                'moonwell-flagship-eth': '0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1',
            },
        },
    },
    SONIC: {
        WS: '0x039e2fb66102314ce7b64ce5ce3e5183bc94ad38',
        USDCe: '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913',
    },
    MAINNET: {
        OWNER: '0x9909ee4947be39c208607d8d2473d68c05cef8f9',
        OPERATOR: '0xf8081dc0f15E6B6508139237a7E9Ed2480Dc7cdc',
        WETH: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
        USDC: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        WBTC: '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599',
        URI: 'https://lite.api.yelay.io/mainnet/metadata/{id}',
        AAVE_V3_POOL: '0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2',
        MORPHO_VAULTS: {
            USDC: {
                'steakhouse-usdc': '0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB',
                'gauntlet-usdc-core': '0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458',
            },
            WETH: {
                'mev-capital-weth': '0x9a8bC3B04b7f3D87cfC09ba407dCED575f2d61D8',
                'gauntlet-weth-core': '0x4881Ef0BF6d2365D3dd6499ccd7532bcdBCE0658',
            },
            WBTC: {
                'pendle-wbtc': '0x2f1aBb81ed86Be95bcf8178bA62C8e72D6834775',
                'gauntlet-wbtc-core': '0x443df5eEE3196e9b2Dd77CaBd3eA76C3dee8f9b2',
            },
        },
    },
};

export const IMPLEMENTATION_STORAGE_SLOT =
    '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';

export const ROLES = {
    STRATEGY_AUTHORITY: ethers.id('STRATEGY_AUTHORITY'),
    FUNDS_OPERATOR: ethers.id('FUNDS_OPERATOR'),
    QUEUES_OPERATOR: ethers.id('QUEUES_OPERATOR'),
    SWAP_REWARDS_OPERATOR: ethers.id('SWAP_REWARDS_OPERATOR'),
    PAUSER: ethers.id('PAUSER'),
    UNPAUSER: ethers.id('UNPAUSER'),
};
