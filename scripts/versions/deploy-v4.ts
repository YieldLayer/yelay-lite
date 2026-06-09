import { ethers, upgrades } from 'hardhat';
import { deployAccessFacet, deployFundsFacet, deployManagementFacet } from '../utils/deploy';
import fs from 'fs';
import path from 'path';
import { getContractsPath } from '../utils/getters';
import { isTesting } from '../utils/common';

async function main() {
    const merklDistributor = ''; //TODO set

    const [deployer] = await ethers.getSigners();
    const chainId = Number((await deployer.provider!.getNetwork()).chainId);
    const testing = isTesting();
    const deploymentPath = getContractsPath(chainId, testing);

    const deploymentData = JSON.parse(fs.readFileSync(path.resolve(deploymentPath), 'utf8'));

    console.log('Deploying access facet...');
    const accessFacet = await deployAccessFacet(deployer);
    console.log('AccessFacet deployed at:', accessFacet);
    deploymentData.accessFacet = accessFacet;

    console.log('Deploying funds facet...');
    const fundsFacet = await deployFundsFacet(
        deployer,
        deploymentData.swapper.proxy,
        merklDistributor,
    );
    console.log('FundsFacet deployed at:', fundsFacet);
    deploymentData.fundsFacet = fundsFacet;

    console.log('Deploying management facet...');
    const managementFacet = await deployManagementFacet(deployer);
    console.log('ManagementFacet deployed at:', managementFacet);
    deploymentData.managementFacet = managementFacet;

    console.log('Deploying yield extractor implementation...');
    const yieldExtractorFactory = await ethers.getContractFactory('YieldExtractor', deployer);
    const yieldExtractorImplementationResult =
        await upgrades.deployImplementation(yieldExtractorFactory);
    let yieldExtractorImplementation: string;
    if (typeof yieldExtractorImplementationResult === 'string') {
        yieldExtractorImplementation = yieldExtractorImplementationResult;
    } else {
        const receipt = await yieldExtractorImplementationResult.wait();
        if (!receipt?.contractAddress) {
            throw new Error('Contract address not found in transaction receipt');
        }
        yieldExtractorImplementation = receipt.contractAddress;
    }
    console.log('YieldExtractor implementation deployed at:', yieldExtractorImplementation);
    deploymentData.yieldExtractor.implementation = yieldExtractorImplementation;

    console.log('Deploying ERC4626 plugin implementation...');
    const erc4626Plugin = await ethers.getContractFactory('ERC4626Plugin', deployer);
    const erc4626PluginImplementation = await erc4626Plugin
        .deploy(deploymentData.yieldExtractor.proxy)
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
    console.log('ERC4626Plugin implementation deployed at:', erc4626PluginImplementation);
    deploymentData.erc4626Plugin.implementation = erc4626PluginImplementation;

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
