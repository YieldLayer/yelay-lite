import { ethers, network } from 'hardhat';
import { getExpectedAddresses } from './constants';
import { checkSetup } from './utils/checks';
import { getContracts } from './utils/getters';

async function main() {
    const chainId = network.config.chainId!;
    const test = process.env.TEST === 'true';

    const contracts = await getContracts(chainId, test);
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
