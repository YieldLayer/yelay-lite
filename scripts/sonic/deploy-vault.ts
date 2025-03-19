import fs from 'fs';
import { ethers } from 'hardhat';
import contracts from '../../deployments/sonic.json';
import { IYelayLiteVault__factory } from '../../typechain-types';
import { ADDRESSES, ROLES } from '../constants';
import { prepareSetSelectorFacets } from './../utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();
    const asset = 'USDCe';
    const uri = 'https://lite.yelay.io/sonic/metadata/{id}';

    const yelayLiteVault = await ethers
        .getContractFactory('YelayLiteVault', deployer)
        .then((f) =>
            f.deploy(
                deployer.address,
                contracts.ownerFacet,
                ADDRESSES[146][asset],
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
            fundsFacet: contracts.fundsFacet,
            managementFacet: contracts.managementFacet,
            accessFacet: contracts.accessFacet,
            clientsFacet: contracts.clientsFacet,
        }),
        yelayLiteVault.grantRole.populateTransaction(ROLES.FUNDS_OPERATOR, deployer.address),
        yelayLiteVault.grantRole.populateTransaction(ROLES.STRATEGY_AUTHORITY, deployer.address),
        yelayLiteVault.grantRole.populateTransaction(ROLES.QUEUES_OPERATOR, deployer.address),
    ]);

    await yelayLiteVault.multicall(data.map((d) => d.data));

    // @ts-ignore
    contracts.vaults[asset] = await yelayLiteVault.getAddress();

    fs.writeFileSync('./deployments/sonic.json', JSON.stringify(contracts, null, 4) + '\n');
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
