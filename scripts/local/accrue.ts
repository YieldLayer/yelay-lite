import { ethers } from 'hardhat';
import contracts from '../../deployments/local.json';
import { IYelayLiteVault__factory, LibErrors__factory } from '../../typechain-types';

async function main() {
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.yelayLiteVault, deployer);
    try {
        const tx = await yelayLiteVault.accrueFee();
        const receipt = await tx.wait(1);
        if (receipt?.status === 1) {
            console.log('Tx successful');
        } else {
            console.log('Tx failed');
        }
    } catch (error: any) {
        const parsedError = LibErrors__factory.createInterface().parseError(error.data);
        if (parsedError) {
            console.error(`Error: ${parsedError.name}`);
        } else {
            console.error(`Error: ${error}`);
            throw new Error('Failed call');
        }
    }
}

main()
    .then(() => {
        console.log('Done');
    })
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
