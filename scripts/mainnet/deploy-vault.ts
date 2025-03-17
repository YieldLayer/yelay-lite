import { ethers } from 'hardhat';
import contracts from '../../deployments/mainnet.json';
import { ADDRESSES } from '../constants';
import { deployVault } from '../utils';

async function main() {
    const asset = 'WBTC';
    const [deployer] = await ethers.getSigners();

    await deployVault(
        deployer,
        contracts,
        {
            underlyingAsset: ADDRESSES.MAINNET[asset],
            yieldExtractor: ADDRESSES.MAINNET.OWNER,
            uri: ADDRESSES.MAINNET.URI,
        },
        asset,
        './deployments/mainnet.json',
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
