import fs from 'fs';
import { ethers } from 'hardhat';
import contracts from '../../deployments/base-async.json';
import { ADDRESSES } from '../constants';
import { deployAsyncFundsFacet, deployCCTPV2Facet } from '../utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();

    const asyncFundsFacet = await deployAsyncFundsFacet(
        deployer,
        contracts.swapper.proxy,
        ADDRESSES[8453].MERKL,
    );
    const cctpV2Facet = await deployCCTPV2Facet(deployer);

    // @ts-ignore
    contracts.asyncFundsFacet = asyncFundsFacet;
    // @ts-ignore
    contracts.cctpV2Facet = cctpV2Facet;

    fs.writeFileSync('./deployments/base-async.json', JSON.stringify(contracts));
}

main();
