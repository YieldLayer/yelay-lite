import fs from 'fs';
import { ethers } from 'hardhat';
import contracts from '../../deployments/mainnet.json';
import { ADDRESSES } from '../constants';
import { deployMorphoVaultStrategy } from './../utils/deploy';

const data = {
    USDC: ['steakhouse-usdc', 'gauntlet-usdc-core'],
    WETH: ['mev-capital-weth', 'gauntlet-weth-core'],
    WBTC: ['pendle-wbtc', 'gauntlet-wbtc-core'],
} as const;

const asset = 'WBTC';

async function main() {
    const [deployer] = await ethers.getSigners();

    for (const vault of data[asset]) {
        const morphoVault = await deployMorphoVaultStrategy(
            deployer,
            ADDRESSES.MAINNET.MORPHO_VAULTS[asset][vault],
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

    fs.writeFileSync('./deployments/mainnet.json', JSON.stringify(contracts, null, 4) + '\n');
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
