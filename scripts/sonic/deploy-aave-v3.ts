import fs from 'fs';
import { ethers } from 'hardhat';
import contracts from '../../deployments/sonic.json';
import { ADDRESSES } from '../constants';
import { deployAaveV3Strategy } from '../utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();

    const aaveV3 = await deployAaveV3Strategy(deployer, ADDRESSES[146].AAVE_V3_POOL);

    // @ts-ignore
    contracts.strategies.aaveV3 = aaveV3;

    fs.writeFileSync('./deployments/sonic.json', JSON.stringify(contracts, null, 4) + '\n');
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
