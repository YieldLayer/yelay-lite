import { ethers } from 'hardhat';
import { ADDRESSES } from '../constants';
import { deployInfra } from '../utils';

async function main() {
    const [deployer] = await ethers.getSigners();

    await deployInfra(
        deployer,
        ADDRESSES.MAINNET.OWNER,
        ADDRESSES.MAINNET.WETH,
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
