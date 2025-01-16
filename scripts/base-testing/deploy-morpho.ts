import fs from 'fs';
import { ethers } from 'hardhat';
import s from '../../deployments/base-strategies.json';
import { MORPHO_BASE } from './constants';

const strategies = s as Record<string, string>;

async function main() {
    const [deployer] = await ethers.getSigners();

    const f = await ethers.getContractFactory('MorphoBlueStrategy', deployer);
    const morphoStrategy = await f.deploy(MORPHO_BASE);
    await morphoStrategy.waitForDeployment();

    strategies['morpho-blue'] = await morphoStrategy.getAddress();

    fs.writeFileSync(
        './deployments/base-strategies.json',
        JSON.stringify(strategies, null, 4) + '\n',
    );
}

main();
