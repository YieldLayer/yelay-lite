import fs from 'fs';
import { ethers } from 'hardhat';
import contracts from '../../deployments/avalanche.json';
import { ADDRESSES } from '../constants';
import { deployAaveV3Strategy, deployERC4626Strategy } from '../utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();

    const aaveV3 = await deployAaveV3Strategy(deployer, ADDRESSES[43114].AAVE_V3_POOL);
    console.log('AaveV3 deployed at:', aaveV3);
    // @ts-ignore
    contracts.strategies.aaveV3 = aaveV3;

    const erc4626Strategy = await deployERC4626Strategy(deployer);
    console.log('Erc4626Strategy deployed at:', erc4626Strategy);
    // @ts-ignore
    contracts.strategies.erc4626 = erc4626Strategy;

    fs.writeFileSync('./deployments/avalanche.json', JSON.stringify(contracts, null, 4) + '\n');
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
