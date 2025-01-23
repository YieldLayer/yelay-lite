import fs from 'fs';
import { ethers, upgrades } from 'hardhat';

import { IYelayLiteVault__factory, Swapper } from '../../typechain-types';
import { Contracts } from '../types';
import { convertToAddresses, deployFacets, setSelectorFacets } from '../utils';
import { USDC_ADDRESS_BASE } from './constants';

async function main() {
    const [deployer] = await ethers.getSigners();

    const swapperFactory = await ethers.getContractFactory('Swapper', deployer);
    const swapper = (await upgrades.deployProxy(swapperFactory, [deployer.address], {
        kind: 'uups',
    })) as unknown as Swapper;

    const { ownerFacet, fundsFacet, accessFacet, managementFacet, clientsFacet } =
        await deployFacets(deployer, swapper);

    const yelayLiteVault = await ethers
        .getContractFactory('YelayLiteVault', deployer)
        .then((f) =>
            f.deploy(
                deployer.address,
                ownerFacet.getAddress(),
                USDC_ADDRESS_BASE,
                deployer.address,
                'test',
            ),
        )
        .then(async (c) => {
            const d = await c.waitForDeployment();
            const tx = await ethers.provider.getTransaction(d.deploymentTransaction()!.hash);
            console.log(`Vault creation blocknumber: ${tx?.blockNumber}`);
            const block = await ethers.provider.getBlock(tx!.blockNumber!);
            console.log(`Timestamp: ${block?.timestamp}`);
            return d.getAddress();
        })
        .then((a) => IYelayLiteVault__factory.connect(a, deployer));

    await setSelectorFacets({
        yelayLiteVault,
        fundsFacet,
        managementFacet,
        accessFacet,
        clientsFacet,
    });

    await yelayLiteVault.createClient(deployer.address, 1000, ethers.encodeBytes32String('test'));

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

    const contracts: Contracts = {
        yelayLiteVault,
        fundsFacet,
        accessFacet,
        managementFacet,
        clientsFacet,
        ownerFacet,
        swapper,
    };

    fs.writeFileSync(
        './deployments/base-testing.json',
        JSON.stringify(await convertToAddresses(contracts), null, 4) + '\n',
    );

    console.log('Successful base-testing deployment');
}

main();
