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
        base: {
            chainId: 8453,
            url: process.env.BASE_URL!,
            accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
        },
    },
    etherscan: {
        apiKey: {
            base: process.env.BASESCAN_API_KEY!,
        },
    },
    sourcify: {
        enabled: false,
    },
};

export default config;
