import dotenv from 'dotenv';
dotenv.config();
//
import '@nomicfoundation/hardhat-foundry';
import '@nomicfoundation/hardhat-toolbox';
import '@openzeppelin/hardhat-upgrades';
import { HardhatUserConfig } from 'hardhat/config';

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.28',
        settings: {
            evmVersion: 'cancun',
            optimizer: {
                enabled: true,
                runs: 10000,
            },
        },
    },
    networks: {
        mainnet: {
            chainId: 1,
            url: process.env.MAINNET_URL!,
            accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
        },
        base: {
            chainId: 8453,
            url: process.env.BASE_URL!,
            accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
        },
        sonic: {
            chainId: 146,
            url: process.env.SONIC_URL!,
            accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
        },
        arbitrum: {
            chainId: 42161,
            url: process.env.ARBITRUM_URL!,
            accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
        },
        avalanche: {
            chainId: 43114,
            url: process.env.AVALANCHE_URL!,
            accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
        },
        snowtrace: {
            chainId: 43114,
            url: 'https://api.avax.network/ext/bc/C/rpc',
            accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
        },
    },
    etherscan: {
        apiKey: {
            mainnet: process.env.ETHERSCAN_API_KEY!,
            base: process.env.ETHERSCAN_API_KEY!,
            arbitrum: process.env.ETHERSCAN_API_KEY!,
            avalanche: process.env.ETHERSCAN_API_KEY!,
            sonic: process.env.ETHERSCAN_API_KEY!,
            snowtrace: 'snowtrace',
        },
        customChains: [
            {
                network: 'sonic',
                chainId: 146,
                urls: {
                    apiURL: 'https://api.sonicscan.org/api',
                    browserURL: 'https://sonicscan.org',
                },
            },
            {
                network: 'snowtrace',
                chainId: 43114,
                urls: {
                    apiURL: 'https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan',
                    browserURL: 'https://snowtrace.io',
                },
            },
        ],
    },
    sourcify: {
        enabled: false,
    },
};

export default config;
