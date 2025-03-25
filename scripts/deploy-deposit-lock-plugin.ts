import { ethers } from 'hardhat';
import { deployDepositLockPlugin } from './utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();
    await deployDepositLockPlugin(deployer);
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
