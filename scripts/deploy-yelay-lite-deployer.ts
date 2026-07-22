import { ethers } from 'hardhat';
import { deployYelayLiteDeployer } from './utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();
    await deployYelayLiteDeployer(deployer);
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
