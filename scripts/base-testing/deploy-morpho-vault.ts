import fs from 'fs';
import { ethers } from 'hardhat';
import contracts from '../../deployments/base-testing.json';
import { ADDRESSES } from '../constants';
import { deployMorphoVaultStrategy } from './../utils/deploy';

const data = {
    USDC: ['steakhouse-usdc', 'gauntlet-usdc-prime', 'gauntlet-usdc-core'],
    WETH: ['ionic-ecosystem-weth', 'moonwell-flagship-eth'],
} as const;

const asset = 'WETH';

async function main() {
    const [deployer] = await ethers.getSigners();

    for (const vault of data[asset]) {
        const morphoVault = await deployMorphoVaultStrategy(
            deployer,
            ADDRESSES.BASE.MORHO_VAULTS[asset][vault],
        );

        // @ts-ignore
        if (!contracts.strategies.morphoVaults) {
            // @ts-ignore
            contracts.strategies.morphoVaults = {};
        }
        // @ts-ignore
        if (!contracts.strategies.morphoVaults[asset]) {
            // @ts-ignore
            contracts.strategies.morphoVaults[asset] = {};
        }
        // @ts-ignore
        contracts.strategies.morphoVaults[asset][vault] = morphoVault;
    }

    fs.writeFileSync('./deployments/base-testing.json', JSON.stringify(contracts, null, 4) + '\n');
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
