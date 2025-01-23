import { ethers } from 'hardhat';
import contracts from '../../deployments/base-testing.json';
import { IYelayLiteVault__factory } from '../../typechain-types';

async function main() {
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.yelayLiteVault, deployer);
    // await yelayLiteVault.createClient(
    //     '0xb20d9258b8f171989915De8Cd5d0ff228B1CA194',
    //     10000,
    //     ethers.encodeBytes32String('perq'),
    // );
    await yelayLiteVault
        .ownerToClientData('0xb20d9258b8f171989915De8Cd5d0ff228B1CA194')
        .then(console.log);
}

main();
