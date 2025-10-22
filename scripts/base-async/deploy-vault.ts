import fs from 'fs';
import { ethers, upgrades } from 'hardhat';
import contracts from '../../deployments/base-async.json';
import { ADDRESSES, IMPLEMENTATION_STORAGE_SLOT } from '../constants';

async function main() {
    const [deployer] = await ethers.getSigners();

    const yieldExtractorFactory = await ethers.getContractFactory('YieldExtractor', deployer);
    const yieldExtractor = await upgrades
        .deployProxy(yieldExtractorFactory, [deployer.address, deployer.address], {
            kind: 'uups',
        })
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());

    const yieldExtractorImplementation = await deployer
        .provider!.getStorage(yieldExtractor, IMPLEMENTATION_STORAGE_SLOT)
        .then((r) => ethers.dataSlice(r, 12));

    // @ts-ignore
    contracts.yieldExtractor = {
        proxy: yieldExtractor,
        implementation: yieldExtractorImplementation,
    };

    const yelayLiteVault = await ethers
        .getContractFactory('YelayLiteVault', deployer)
        .then((f) =>
            f.deploy(
                deployer.address,
                contracts.ownerFacet,
                ADDRESSES[8453].USDC,
                yieldExtractor,
                ADDRESSES[8453].URI,
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
        });

    // @ts-ignore
    contracts.vaults['USDC'] = yelayLiteVault;
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
