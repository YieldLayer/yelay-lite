import fs from 'fs';
import { ethers, upgrades } from 'hardhat';
import contracts from '../../deployments/base-production.json';
import { ADDRESSES, IMPLEMENTATION_STORAGE_SLOT } from '../constants';

async function main() {
    const [deployer] = await ethers.getSigners();

    const ownerAddress = deployer.address;
    const wethAddress = ADDRESSES[8453].WETH;

    const swapperFactory = await ethers.getContractFactory('Swapper', deployer);
    const swapper = await upgrades
        .deployProxy(swapperFactory, [ownerAddress], {
            kind: 'uups',
            unsafeAllow: ['state-variable-immutable'],
        })
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());

    const swapperImplementationAddress = await deployer
        .provider!.getStorage(swapper, IMPLEMENTATION_STORAGE_SLOT)
        .then((r) => ethers.dataSlice(r, 12));

    const vaultWrapperFactory = await ethers.getContractFactory('VaultWrapper', deployer);
    const vaultWrapper = await upgrades
        .deployProxy(vaultWrapperFactory, [ownerAddress], {
            kind: 'uups',
            constructorArgs: [wethAddress, swapper],
            unsafeAllow: ['state-variable-immutable'],
        })
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());

    const vaultWrapperImplementationAddress = await deployer
        .provider!.getStorage(vaultWrapper, IMPLEMENTATION_STORAGE_SLOT)
        .then((r) => ethers.dataSlice(r, 12));

    contracts.vaultWrapper.proxy = vaultWrapper;
    contracts.vaultWrapper.implementation = vaultWrapperImplementationAddress;

    contracts.swapper.proxy = swapper;
    contracts.swapper.implementation = swapperImplementationAddress;

    fs.writeFileSync(
        './deployments/base-production.json',
        JSON.stringify(contracts, null, 4) + '\n',
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
