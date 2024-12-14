import dotenv from 'dotenv';
dotenv.config();
//
import '@nomicfoundation/hardhat-foundry';
import '@nomicfoundation/hardhat-toolbox';
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
        },
    },
};

export default config;
