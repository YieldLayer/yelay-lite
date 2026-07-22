import { ethers } from 'hardhat';
import mainnetContracts from '../deployments/mainnet.json';

export const ADDRESSES = {
    1: {
        OWNER: '0x9909ee4947be39c208607d8d2473d68c05cef8f9',
        FUNDS_OPERATORS: [
            '0xB32d12d39b1855b11566Dba07Db7A33f5146b3e6',
            '0x225F31863b892dd747D06c1F46DcebFa73907870',
            '0xbB355ffc23784751f2507c1dFA74aEC4CD7628c8',
            '0x46FF1b2B030201F572E22FC18c26974EC8Fe8819',
            '0xc7f5a7bC4878fedF51ca7A45444d74D8c4EA952F',
        ],
        VAULT_FUNDS_OPERATORS: {
            USDC: ['0x60e26Bd94D26Be0cd09b2138257555686C0dEEa0'],
        },
        QUEUE_OPERATORS: [
            '0x225F31863b892dd747D06c1F46DcebFa73907870',
            '0xbB355ffc23784751f2507c1dFA74aEC4CD7628c8',
            '0x46FF1b2B030201F572E22FC18c26974EC8Fe8819',
            '0xc7f5a7bC4878fedF51ca7A45444d74D8c4EA952F',
        ],
        SWAP_REWARDS_OPERATOR: ['0xB32d12d39b1855b11566Dba07Db7A33f5146b3e6'],
        WETH: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
        USDC: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        WBTC: '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599',
        URI: 'https://lite.api.yelay.io/mainnet/metadata/{id}',
        AAVE_V3_POOL: '0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2',
        MORPHO: '0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb',
        ONE_INCH_ROUTER_V6: '0x111111125421cA6dc452d289314280a0f8842A65',
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
        GEARBOX_TOKEN: `0xBa3335588D9403515223F109EdC4eB7269a9Ab5D`,
        YIELD_PUBLISHER: '0xdF8101F15c0317FE5cBaB0fd2C1b05396C6cA94A',
    },
} as const;

export type ExpectedAddresses = {
    owner: string;
    yieldExtractor: string;
    oneInchRouter: string;
    strategyAuthority: string[];
    clientManager: string[];
    fundsOperator: string[];
    vaultFundsOperators?: Record<string, readonly string[]>;
    queueOperator: string[];
    swapRewardsOperator: string[];
    pauser: string[];
    unpauser: string[];
    yieldPublisher: string;
};

export const getExpectedFundsOperators = (
    asset: string,
    {
        fundsOperator,
        vaultFundsOperators,
    }: Pick<ExpectedAddresses, 'fundsOperator' | 'vaultFundsOperators'>,
): string[] => [...fundsOperator, ...(vaultFundsOperators?.[asset] ?? [])];

export const getExpectedAddresses = (chainId: number, test = false): ExpectedAddresses => {
    if (chainId !== 1 || test) {
        throw new Error('Only mainnet is supported');
    }
    return {
        owner: ADDRESSES[chainId].OWNER,
        yieldExtractor: mainnetContracts.yieldExtractor.proxy,
        oneInchRouter: ADDRESSES[chainId].ONE_INCH_ROUTER_V6,
        strategyAuthority: [ADDRESSES[chainId].OWNER],
        clientManager: [ADDRESSES[chainId].OWNER],
        fundsOperator: [ADDRESSES[chainId].OWNER, ...ADDRESSES[chainId].FUNDS_OPERATORS],
        vaultFundsOperators: ADDRESSES[chainId].VAULT_FUNDS_OPERATORS,
        queueOperator: [ADDRESSES[chainId].OWNER, ...ADDRESSES[chainId].QUEUE_OPERATORS],
        swapRewardsOperator: [
            ADDRESSES[chainId].OWNER,
            ...ADDRESSES[chainId].SWAP_REWARDS_OPERATOR,
        ],
        pauser: [ADDRESSES[chainId].OWNER],
        unpauser: [ADDRESSES[chainId].OWNER],
        yieldPublisher: ADDRESSES[chainId].YIELD_PUBLISHER,
    };
};

export const IMPLEMENTATION_STORAGE_SLOT =
    '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';

export const ROLES = {
    STRATEGY_AUTHORITY: ethers.id('STRATEGY_AUTHORITY'),
    CLIENT_MANAGER: ethers.id('CLIENT_MANAGER'),
    FUNDS_OPERATOR: ethers.id('FUNDS_OPERATOR'),
    QUEUES_OPERATOR: ethers.id('QUEUES_OPERATOR'),
    SWAP_REWARDS_OPERATOR: ethers.id('SWAP_REWARDS_OPERATOR'),
    PAUSER: ethers.id('PAUSER'),
    UNPAUSER: ethers.id('UNPAUSER'),
    YIELD_PUBLISHER: ethers.id('YIELD_PUBLISHER'),
};
