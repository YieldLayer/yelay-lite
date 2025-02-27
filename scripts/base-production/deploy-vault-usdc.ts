import fs from 'fs';
import { ethers } from 'hardhat';
import contracts from '../../deployments/base-production.json';
import {
    AccessFacet__factory,
    ClientsFacet__factory,
    FundsFacet__factory,
    IYelayLiteVault__factory,
    ManagementFacet__factory,
} from '../../typechain-types';
import { ADDRESSES } from '../constants';
import { prepareSetSelectorFacets } from '../utils';

async function main() {
    const [deployer] = await ethers.getSigners();
    const asset = 'USDC';
    const uri = 'https://lite.yelay.io/base/metadata/{id}';

    const yelayLiteVault = await ethers
        .getContractFactory('YelayLiteVault', deployer)
        .then((f) =>
            f.deploy(
                deployer.address,
                contracts.ownerFacet,
                ADDRESSES.BASE[asset],
                deployer.address,
                uri,
            ),
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

    const data = await Promise.all([
        prepareSetSelectorFacets({
            yelayLiteVault,
            fundsFacet: FundsFacet__factory.connect(contracts.fundsFacet),
            managementFacet: ManagementFacet__factory.connect(contracts.managementFacet),
            accessFacet: AccessFacet__factory.connect(contracts.accessFacet),
            clientsFacet: ClientsFacet__factory.connect(contracts.clientsFacet),
        }),
    ]);

    await yelayLiteVault.multicall(data.map((d) => d.data));

    // @ts-ignore
    contracts.vaults[asset] = await yelayLiteVault.getAddress();

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
