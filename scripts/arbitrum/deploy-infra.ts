import { ethers } from 'hardhat';
import { ADDRESSES } from '../constants';
import { deployInfraV2 } from './../utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();

    await deployInfraV2(
        deployer,
        ADDRESSES[42161].OWNER,
        ADDRESSES[42161].WETH,
        ADDRESSES[42161].MERKL,
        './deployments/arbitrum.json',
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
