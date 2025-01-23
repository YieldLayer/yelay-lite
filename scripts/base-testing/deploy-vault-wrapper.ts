import fs from 'fs';
import { ethers, upgrades } from 'hardhat';

import c from '../../deployments/base-testing.json';

import { VaultWrapper } from '../../typechain-types';
import { WETH_ADDRESS_BASE } from './constants';

async function main() {
    const [deployer] = await ethers.getSigners();

    const vaultWrapperFactory = await ethers.getContractFactory('VaultWrapper', deployer);
    const vaultWrapper = (await upgrades.deployProxy(vaultWrapperFactory, [deployer.address], {
        kind: 'uups',
        constructorArgs: [WETH_ADDRESS_BASE, c.swapper],
    })) as unknown as VaultWrapper;

    (c as Record<string, string | Record<string, string>>)['vaultWrapper'] =
        await vaultWrapper.getAddress();

    fs.writeFileSync('./deployments/base-testing.json', JSON.stringify(c, null, 4) + '\n');

    console.log('Ready');
}

main();
