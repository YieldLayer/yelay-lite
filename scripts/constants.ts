import { ethers } from 'hardhat';

export const ADDRESSES = {
    BASE: {
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
