import dotenv from 'dotenv';
dotenv.config();
//
import '@nomicfoundation/hardhat-foundry';
import '@nomicfoundation/hardhat-toolbox';
import '@openzeppelin/hardhat-upgrades';
import { HardhatUserConfig, task, types } from 'hardhat/config';
import { deposit, migrate, redeem } from './scripts/local/actions';

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

task('deposit', 'Deposit into YelayLiteVault on local fork')
    .addPositionalParam('userIndex', 'Index of user(1-3)', undefined, types.int)
    .addPositionalParam('amount', 'Amount in decimal format', undefined, types.int)
    .addPositionalParam('projectId', 'Amount in decimal format', 1, types.int, true)
    .setAction(deposit);

task('redeem', 'Redeem from YelayLiteVault on local fork')
    .addPositionalParam('userIndex', 'Index of user(1-3)', undefined, types.int)
    .addPositionalParam('amount', 'Amount in decimal format', undefined, types.int)
    .addPositionalParam('projectId', 'projectId', 1, types.int, true)
    .setAction(redeem);

task('migrate', 'Migrate project in YelayLiteVault on local fork')
    .addPositionalParam('userIndex', 'Index of user(1-3)', undefined, types.int)
    .addPositionalParam('amount', 'Amount in decimal format', undefined, types.int)
    .addPositionalParam('fromProjectId', 'projectId to migrate from', undefined, types.int)
    .addPositionalParam('toProjectId', 'projectId to migrate to', undefined, types.int)
    .setAction(migrate);

export default config;
