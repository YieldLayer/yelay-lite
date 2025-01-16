import fs from 'fs';
import { ethers } from 'hardhat';
import s from '../../deployments/base-strategies.json';
import { AAVE_V3_POOL_BASE } from './constants';

const strategies = s as Record<string, string>;

async function main() {
    const [deployer] = await ethers.getSigners();

    const aaveStrategyFactory = await ethers.getContractFactory('AaveV3Strategy', deployer);
    const aaveStrategy = await aaveStrategyFactory.deploy(AAVE_V3_POOL_BASE);
    await aaveStrategy.waitForDeployment();

    strategies['aave-v3'] = await aaveStrategy.getAddress();

    fs.writeFileSync(
        './deployments/base-strategies.json',
        JSON.stringify(strategies, null, 4) + '\n',
    );
}

main();
