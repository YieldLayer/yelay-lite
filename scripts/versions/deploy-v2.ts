import { ethers } from 'hardhat';
import {
    deployAccessFacet,
    deployClientsFacet,
    deployFundsFacet,
    deployManagementFacet,
    deployAaveV3Strategy,
    deployMorphoBlueStrategy,
    deployGearboxV3Strategy,
    deployERC4626Strategy,
} from '../utils/deploy';
import { ADDRESSES } from '../constants';
import fs from 'fs';
import path from 'path';
import { getContractsPath } from '../utils/getters';

async function main() {
    //Set before running
    const chainId = 1;
    const testing = false;
    const deploymentPath = getContractsPath(chainId, testing);

    const [deployer] = await ethers.getSigners();
    const deploymentData = JSON.parse(fs.readFileSync(path.resolve(deploymentPath), 'utf8'));

    console.log('Deploying facets...');

    const clientsFacet = await deployClientsFacet(deployer);
    console.log('ClientsFacet deployed at:', clientsFacet);
    deploymentData.clientsFacet = clientsFacet;

    const fundsFacet = await deployFundsFacet(deployer, deploymentData.swapper.proxy);
    console.log('FundsFacet deployed at:', fundsFacet);
    deploymentData.fundsFacet = fundsFacet;

    const managementFacet = await deployManagementFacet(deployer);
    console.log('ManagementFacet deployed at:', managementFacet);
    deploymentData.managementFacet = managementFacet;

    console.log('Deploying strategies...');
    const aaveV3Strategy = await deployAaveV3Strategy(deployer, ADDRESSES[chainId].AAVE_V3_POOL);
    console.log('AaveV3Strategy deployed at:', aaveV3Strategy);
    deploymentData.strategies.aaveV3 = aaveV3Strategy;

    const morphoBlueStrategy = await deployMorphoBlueStrategy(deployer, ADDRESSES[chainId].MORPHO);
    console.log('MorphoBlueStrategy deployed at:', morphoBlueStrategy);
    deploymentData.strategies.morpho = morphoBlueStrategy;

    const erc4626Strategy = await deployERC4626Strategy(deployer);
    console.log('Erc4626Strategy deployed at:', erc4626Strategy);
    deploymentData.strategies.erc4626 = erc4626Strategy;

    const gearboxV3Strategy = await deployGearboxV3Strategy(
        deployer,
        ADDRESSES[chainId].GEARBOX_TOKEN,
    );
    deploymentData.strategies.gearboxV3 = gearboxV3Strategy;
    console.log('GearboxV3Strategy deployed at:', gearboxV3Strategy);

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
