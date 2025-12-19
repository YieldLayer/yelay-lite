import { ethers } from 'hardhat';
import { ADDRESSES } from '../constants';
import { deployInfraV2 } from './../utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();

    await deployInfraV2(
        deployer,
        deployer.address,
        ADDRESSES[8453].WETH,
        ADDRESSES[8453].MERKL,
        './deployments/base-async.json',
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
