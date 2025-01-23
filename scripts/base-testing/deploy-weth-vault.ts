import fs from 'fs';
import { ethers } from 'hardhat';

import c from '../../deployments/base-testing.json';

import {
    AccessFacet__factory,
    ClientsFacet__factory,
    FundsFacet__factory,
    IYelayLiteVault__factory,
    ManagementFacet__factory,
} from '../../typechain-types';
import { setSelectorFacets } from '../utils';
import { WETH_ADDRESS_BASE } from './constants';

async function main() {
    const [deployer] = await ethers.getSigners();

    const yelayLiteVault = await ethers
        .getContractFactory('YelayLiteVault', deployer)
        .then((f) =>
            f.deploy(deployer.address, c.ownerFacet, WETH_ADDRESS_BASE, deployer.address, 'test'),
        )
        .then(async (c) => {
            const d = await c.waitForDeployment();
            const tx = await ethers.provider.getTransaction(d.deploymentTransaction()!.hash);
            console.log(`Vault: ${await c.getAddress()}`);
            console.log(`Vault creation blocknumber: ${tx?.blockNumber}`);
            const block = await ethers.provider.getBlock(tx!.blockNumber!);
            console.log(`Timestamp: ${block?.timestamp}`);
            return d.getAddress();
        })
        .then((a) => IYelayLiteVault__factory.connect(a, deployer));

    await setSelectorFacets({
        yelayLiteVault,
        fundsFacet: FundsFacet__factory.connect(c.fundsFacet),
        managementFacet: ManagementFacet__factory.connect(c.managementFacet),
        accessFacet: AccessFacet__factory.connect(c.accessFacet),
        clientsFacet: ClientsFacet__factory.connect(c.clientsFacet),
    });

    await yelayLiteVault.grantRole(
        '0xbf935b513649871c60054e0279e4e5798d3dfd05785c3c3c5b311fb39ec270fe',
        deployer.address,
    );
    await yelayLiteVault.grantRole(
        '0xb95e9900cc6e2c54ae5b00d8f86008697b24bf67652a40653ea0c09c6fc4a856',
        deployer.address,
    );
    await yelayLiteVault.grantRole(
        '0xffd2865c3eadba5ddbf1543e65a692d7001b37f737db7363a54642156548df64',
        deployer.address,
    );

    (c as Record<string, string | Record<string, string>>)['vaults'] = {
        weth: await yelayLiteVault.getAddress(),
    };

    fs.writeFileSync('./deployments/base-testing.json', JSON.stringify(c, null, 4) + '\n');

    console.log('Ready');
}

main();
