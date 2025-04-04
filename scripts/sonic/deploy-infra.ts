import { ethers } from 'hardhat';
import { ADDRESSES } from '../constants';
import { deployInfra } from './../utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();

    await deployInfra(
        deployer,
        ADDRESSES[146].OWNER,
        ADDRESSES[146].WS,
        './deployments/sonic.json',
    );
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
