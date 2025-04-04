import { ethers } from 'hardhat';
import contracts from '../../deployments/sonic.json';
import { ADDRESSES } from '../constants';
import { deployVault } from './../utils/deploy';

async function main() {
    const asset = 'WS';
    const [deployer] = await ethers.getSigners();

    await deployVault(
        deployer,
        contracts,
        {
            underlyingAsset: ADDRESSES[146][asset],
            yieldExtractor: ADDRESSES[146].OWNER,
            uri: ADDRESSES[146].URI,
        },
        asset,
        './deployments/sonic.json',
    );
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
