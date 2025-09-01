import { ethers } from 'hardhat';
import contracts from '../../deployments/avalanche.json';
import { ADDRESSES } from '../constants';
import { deployVault } from '../utils/deploy';

async function main() {
    const assets = ['USDC', 'WETH'] as const;
    const [deployer] = await ethers.getSigners();

    for (const asset of assets) {
        await deployVault(
            deployer,
            contracts,
            {
                underlyingAsset: ADDRESSES[43114][asset],
                yieldExtractor: contracts.yieldExtractor.proxy,
                uri: ADDRESSES[43114].URI,
            },
            asset,
            './deployments/avalanche.json',
        );
    }
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
