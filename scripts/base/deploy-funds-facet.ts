import fs from 'fs';
import { ethers } from 'hardhat';
import contracts from '../../deployments/base-production.json';

async function main() {
    const [deployer] = await ethers.getSigners();

    const fundsFacet = await ethers
        .getContractFactory('FundsFacet', deployer)
        .then((f) => f.deploy(contracts.swapper.proxy))
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());

    contracts.fundsFacet = fundsFacet;

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
