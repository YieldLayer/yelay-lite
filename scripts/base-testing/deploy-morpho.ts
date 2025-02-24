import fs from 'fs';
import { ethers } from 'hardhat';
import contracts from '../../deployments/base-testing.json';
import { ADDRESSES } from '../constants';
import { deployMorphoBlueStrategy } from '../utils';

async function main() {
    const [deployer] = await ethers.getSigners();

    const morpho = await deployMorphoBlueStrategy(deployer, ADDRESSES.BASE.MORPHO);

    // @ts-ignore
    contracts.strategies.morpho = morpho;

    fs.writeFileSync('./deployments/base-testing.json', JSON.stringify(contracts, null, 4) + '\n');
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
