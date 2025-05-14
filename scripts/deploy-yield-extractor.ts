import { ethers } from 'hardhat';
import { deployYieldExtractor } from './utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();
    await deployYieldExtractor(deployer);
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
