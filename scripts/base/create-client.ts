import { ethers } from 'hardhat';
import contracts from '../../deployments/base-production.json';
import { IYelayLiteVault__factory } from '../../typechain-types';

async function main() {
    const [deployer] = await ethers.getSigners();
    const client = '';
    const clientName = '';
    if (!client || !clientName) {
        throw new Error('No client');
    }
    const vault = contracts.vaults.WETH;
    const yelayLiteVault = IYelayLiteVault__factory.connect(vault, deployer);
    await yelayLiteVault.createClient(client, 10_000, ethers.encodeBytes32String(clientName));
}

main();
