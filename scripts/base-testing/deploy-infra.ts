import { ethers } from 'hardhat';
import { ADDRESSES } from '../constants';
import { deployInfra } from './../utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();

    await deployInfra(
        deployer,
        deployer.address,
        ADDRESSES.BASE.WETH,
        './deployments/base-testing.json',
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
