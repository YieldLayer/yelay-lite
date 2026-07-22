import fs from 'fs';
import { ethers } from 'hardhat';
import ERC1967ProxyArtifact from '@openzeppelin/upgrades-core/artifacts/@openzeppelin/contracts-v5/proxy/ERC1967/ERC1967Proxy.sol/ERC1967Proxy.json';
import { getExpectedAddresses } from './constants';
import { isTesting } from './utils/common';
import { getContracts, getContractsPath } from './utils/getters';

async function main() {
    const [deployer] = await ethers.getSigners();
    const chainId = Number((await deployer.provider!.getNetwork()).chainId);
    const testing = isTesting();
    const contractsPath = getContractsPath(chainId, testing);
    const contracts = await getContracts(contractsPath);

    const implementation = contracts.yieldExtractor?.implementation;
    if (!implementation) {
        throw new Error(`No YieldExtractor implementation for chain ${chainId}`);
    }

    const { owner, yieldPublisher } = getExpectedAddresses(chainId, testing);
    const yieldExtractor = await ethers.getContractFactory('YieldExtractor', deployer);
    const initData = yieldExtractor.interface.encodeFunctionData('initialize', [
        owner,
        yieldPublisher,
    ]);

    const proxy = await new ethers.ContractFactory(
        ERC1967ProxyArtifact.abi,
        ERC1967ProxyArtifact.bytecode,
        deployer,
    )
        .deploy(implementation, initData)
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());

    console.log(`YieldExtractor proxy: ${proxy}`);
    console.log(`Implementation: ${implementation}`);

    contracts.yieldExtractor = { proxy, implementation };
    fs.writeFileSync(contractsPath, JSON.stringify(contracts, null, 4) + '\n');
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
