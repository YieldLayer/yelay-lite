import fs from 'fs';
import { ethers, upgrades } from 'hardhat';
import { IYelayLiteVault__factory, Swapper } from '../typechain-types';
import { USDC_ADDRESS } from './constants';
import { Contracts } from './types';
import { convertToAddresses, deployFacets, initYelayLiteVault, setSelectorFacets } from './utils';

// launch local fork first
// source .env && anvil --fork-url ${MAINNET_URL} --auto-impersonate --block-base-fee-per-gas 1

async function main() {
    const [deployer, _, yieldExtractor] = await ethers.getSigners();

    const swapperFactory = await ethers.getContractFactory('Swapper', deployer);
    const swapper = (await upgrades.deployProxy(swapperFactory, [deployer.address], {
        kind: 'transparent',
    })) as unknown as Swapper;

    const { ownerFacet, tokenFacet, fundsFacet, accessFacet, managementFacet, clientsFacet } =
        await deployFacets(deployer);

    const yelayLiteVaultInit = await ethers
        .getContractFactory('YelayLiteVaultInit', deployer)
        .then((f) => f.deploy());

    const yelayLiteVault = await ethers
        .getContractFactory('YelayLiteVault', deployer)
        .then((f) => f.deploy(deployer.address, ownerFacet.getAddress()))
        .then((c) => c.getAddress())
        .then((a) => IYelayLiteVault__factory.connect(a, deployer));

    await setSelectorFacets({
        yelayLiteVault,
        fundsFacet,
        tokenFacet,
        managementFacet,
        accessFacet,
        clientsFacet,
    });

    await initYelayLiteVault({
        yelayLiteVault,
        yelayLiteVaultInit,
        swapper,
        yieldExtractorAddress: yieldExtractor.address,
        underlyingAssetAddress: USDC_ADDRESS,
        uri: 'test',
    });

    await yelayLiteVault.createClient(deployer.address, 1, 100, ethers.encodeBytes32String('test'));
    await yelayLiteVault.activateProject(1);

    const contracts: Contracts = {
        yelayLiteVault,
        tokenFacet,
        fundsFacet,
        accessFacet,
        managementFacet,
        clientsFacet,
        yelayLiteVaultInit,
        swapper,
    };

    fs.writeFileSync(
        './deployments/local.json',
        JSON.stringify(await convertToAddresses(contracts), null, 4) + '\n',
    );

    console.log('Successful local deployment');
}

main();
