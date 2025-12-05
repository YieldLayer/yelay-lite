import { ethers, upgrades } from 'hardhat';
import {
    deployFundsFacet,
    deployERC4626PluginFactory,
    deployClientsFacet,
    deployOwnerFacet,
} from '../utils/deploy';
import fs from 'fs';
import path from 'path';
import { getContractsPath, getFundsFacetSelectors } from '../utils/getters';
import { isTesting } from '../utils/common';

async function main() {
    const factorySalt = ''; //TODO set
    const dummyImplementationSalt = ''; //TODO set
    const merklDistributor = ''; //TODO set

    const [deployer] = await ethers.getSigners();
    const chainId = Number((await deployer.provider!.getNetwork()).chainId);
    const testing = isTesting();
    const deploymentPath = getContractsPath(chainId, testing);

    const deploymentData = JSON.parse(fs.readFileSync(path.resolve(deploymentPath), 'utf8'));

    console.log('Deploying funds facet...');
    const fundsFacet = await deployFundsFacet(
        deployer,
        deploymentData.swapper.proxy,
        merklDistributor,
    );
    console.log('FundsFacet deployed at:', fundsFacet);
    deploymentData.fundsFacet = fundsFacet;

    console.log('Deploying clients facet...');
    const clientsFacet = await deployClientsFacet(deployer);
    console.log('ClientsFacet deployed at:', clientsFacet);
    deploymentData.clientsFacet = clientsFacet;

    console.log('Deploying owner facet...');
    const ownerFacet = await deployOwnerFacet(deployer);
    console.log('OwnerFacet deployed at:', ownerFacet);
    deploymentData.ownerFacet = ownerFacet;

    console.log('Deploying yield extractor implementation...');
    const yieldExtractorFactory = await ethers.getContractFactory('YieldExtractor', deployer);
    const yieldExtractorImplementationResult =
        await upgrades.deployImplementation(yieldExtractorFactory);
    let yieldExtractorImplementation: string;
    //If it's already deployed, result is the address, otherwise we need to wait for the receipt and get the address
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

    console.log('Deploying deposit lock plugin implementation...');
    const depositLockPluginFactory = await ethers.getContractFactory('DepositLockPlugin', deployer);
    const depositLockPluginImplementationResult =
        await upgrades.deployImplementation(depositLockPluginFactory);
    let depositLockPluginImplementation: string;
    if (typeof depositLockPluginImplementationResult === 'string') {
        depositLockPluginImplementation = depositLockPluginImplementationResult;
    } else {
        const receipt = await depositLockPluginImplementationResult.wait();
        if (!receipt?.contractAddress) {
            throw new Error('Contract address not found in transaction receipt');
        }
        depositLockPluginImplementation = receipt.contractAddress;
    }
    console.log('DepositLockPlugin implementation deployed at:', depositLockPluginImplementation);
    deploymentData.depositLockPlugin.implementation = depositLockPluginImplementation;

    console.log('Deploying ERC4626PluginFactory...');
    const { factory: factoryAddress, implementation: implementationAddress } =
        await deployERC4626PluginFactory(
            deployer,
            deploymentData.yieldExtractor.proxy,
            ethers.keccak256(ethers.toUtf8Bytes(factorySalt)),
            ethers.keccak256(ethers.toUtf8Bytes(dummyImplementationSalt)),
            chainId,
            testing,
        );
    deploymentData.erc4626Plugin = {
        factory: factoryAddress,
        implementation: implementationAddress,
    };

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
