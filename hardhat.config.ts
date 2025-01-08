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
        },
        local: {
            chainId: 1,
            url: process.env.LOCAL_URL!,
            accounts: [
                process.env.LOCAL_DEPLOYER_PRIVATE_KEY!,
                process.env.LOCAL_YIELD_EXTRACTOR_PRIVATE_KEY!,
                process.env.LOCAL_USER1_PRIVATE_KEY!,
                process.env.LOCAL_USER2_PRIVATE_KEY!,
                process.env.LOCAL_USER3_PRIVATE_KEY!,
            ],
            timeout: 5 * 60 * 1000,
        },
    },
};

export default config;
