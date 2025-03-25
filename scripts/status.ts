import { ethers, network } from 'hardhat';
import { getExpectedAddresses } from './constants';
import { checkSetup } from './utils/checks';
import { isTesting } from './utils/common';
import { getContracts, getContractsPath } from './utils/getters';

async function main() {
    const chainId = network.config.chainId!;
    const test = isTesting();

    const contractsPath = getContractsPath(chainId, test);
    const contracts = await getContracts(contractsPath);
    const expectedAddresses = getExpectedAddresses(chainId, test);

    await checkSetup(contracts, ethers.provider, expectedAddresses);
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
