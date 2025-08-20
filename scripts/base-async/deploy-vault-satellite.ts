import fs from 'fs';
import { ethers } from 'hardhat';
import contracts from '../../deployments/base-async.json';
import { ADDRESSES } from '../constants';

async function main() {
    const [deployer] = await ethers.getSigners();

    const yelayLiteVault = await ethers
        .getContractFactory('YelayLiteVault', deployer)
        .then((f) =>
            f.deploy(
                deployer.address,
                contracts.ownerFacet,
                ADDRESSES[8453].USDC,
                deployer.address,
                ADDRESSES[8453].URI,
            ),
        )
        .then(async (c) => {
            const d = await c.waitForDeployment();
            return d.getAddress();
        });

    // @ts-ignore
    contracts.vaults['USDC-satellite'] = yelayLiteVault;
    fs.writeFileSync('./deployments/base-async.json', JSON.stringify(contracts, null, 4) + '\n');
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
