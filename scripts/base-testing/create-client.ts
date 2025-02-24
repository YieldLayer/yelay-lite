import { ethers } from 'hardhat';
import contracts from '../../deployments/base-testing.json';
import { IYelayLiteVault__factory } from '../../typechain-types';

async function main() {
    const [deployer] = await ethers.getSigners();
    const client = '';
    const vault = contracts.vaults.WETH;
    const yelayLiteVault = IYelayLiteVault__factory.connect(vault, deployer);
    await yelayLiteVault.createClient(client, 100, ethers.encodeBytes32String('deployer'));
}

main();
