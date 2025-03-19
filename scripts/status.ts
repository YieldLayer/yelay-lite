import { ethers, network } from 'hardhat';
import { getContracts } from './utils/getters';
import { checkSetup } from './utils/checks';

async function main() {
    const contracts = await getContracts(network.config.chainId!, process.env.TEST === 'true');
    await checkSetup(contracts, ethers.provider);
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
