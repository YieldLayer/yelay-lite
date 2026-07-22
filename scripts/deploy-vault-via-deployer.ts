import { ethers } from 'hardhat';
import { deployVaultViaDeployer } from './utils/deploy';

async function main() {
    const asset = '';
    const salt = '';
    if (!asset || !salt) {
        throw new Error('Set asset and salt before running');
    }

    const [deployer] = await ethers.getSigners();
    await deployVaultViaDeployer(deployer, asset, salt);
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
