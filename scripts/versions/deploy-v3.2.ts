import { ethers } from 'hardhat';
import { IFundsFacet__factory } from '../../typechain-types';
import { deployFundsFacet } from '../utils/deploy';
import fs from 'fs';
import path from 'path';
import { getContractsPath } from '../utils/getters';
import { isTesting } from '../utils/common';

async function main() {
    const [deployer] = await ethers.getSigners();
    const chainId = Number((await deployer.provider!.getNetwork()).chainId);
    const testing = isTesting();
    const deploymentPath = getContractsPath(chainId, testing);

    const deploymentData = JSON.parse(fs.readFileSync(path.resolve(deploymentPath), 'utf8'));

    const merklDistributor = await IFundsFacet__factory.connect(
        deploymentData.fundsFacet,
        deployer,
    ).merklDistributor();

    console.log('Deploying funds facet...');
    const fundsFacet = await deployFundsFacet(
        deployer,
        deploymentData.swapper.proxy,
        merklDistributor,
    );
    console.log('FundsFacet deployed at:', fundsFacet);
    deploymentData.fundsFacet = fundsFacet;

    fs.writeFileSync(path.resolve(deploymentPath), JSON.stringify(deploymentData, null, 4));
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
