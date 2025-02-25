import { ethers } from 'hardhat';
import { ADDRESSES } from '../constants';
import { deployInfra } from '../utils';

async function main() {
    const [deployer] = await ethers.getSigners();

    await deployInfra(deployer, deployer.address, ADDRESSES.SONIC.WS, './deployments/sonic.json');
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
