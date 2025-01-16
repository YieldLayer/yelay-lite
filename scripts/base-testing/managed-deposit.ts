import { ethers } from 'hardhat';
import contracts from '../../deployments/base-testing.json';
import { IYelayLiteVault__factory } from '../../typechain-types';

async function main() {
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.yelayLiteVault, deployer);
    await yelayLiteVault.managedDeposit({ index: 1, amount: ethers.parseUnits('5', 6) });
}

main();
