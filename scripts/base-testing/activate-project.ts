import { ethers } from 'hardhat';
import contracts from '../../deployments/base-testing.json';
import { IYelayLiteVault__factory } from '../../typechain-types';

async function main() {
    const [deployer] = await ethers.getSigners();
    const projectId = 1;
    const vault = contracts.vaults.USDC;

    const yelayLiteVault = IYelayLiteVault__factory.connect(vault, deployer);
    await yelayLiteVault.activateProject(projectId);
}

main();
