import { ethers } from 'hardhat';
import { ADDRESSES } from '../constants';
import { deployInfraV2 } from '../utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();

    await deployInfraV2(
        deployer,
        ADDRESSES[43114].OWNER,
        ADDRESSES[43114].WAVAX,
        ADDRESSES[43114].MERKL,
        './deployments/avalanche.json',
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
