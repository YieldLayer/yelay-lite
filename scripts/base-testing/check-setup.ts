import { ethers } from 'hardhat';
import contracts from '../../deployments/base-testing.json';
import { checkSetup } from '../utils';

async function main() {
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
