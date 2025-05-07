import { ethers } from 'hardhat';
import { deployFeeMRegistrationPlugin } from '../utils/deploy';
import fs from 'fs';
import path from 'path';
import { getContractsPath } from '../utils/getters';

async function main() {
    const [deployer] = await ethers.getSigners();
    const deploymentPath = getContractsPath(146);

    const deploymentData = JSON.parse(fs.readFileSync(path.resolve(deploymentPath), 'utf8'));
    const feeMRegistrationPlugin = await deployFeeMRegistrationPlugin(deployer);
    console.log('FeeMRegistrationPlugin deployed at:', feeMRegistrationPlugin);
    deploymentData.feeMRegistrationPlugin = feeMRegistrationPlugin;

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
