import { ethers } from 'hardhat';
import contracts from '../../deployments/base-production.json';
import { LibErrors__factory, VaultWrapper__factory } from '../../typechain-types';

const PROJECT_ID = 1;
const AMOUNT = ethers.parseEther('0.01');

async function main() {
    const [deployer] = await ethers.getSigners();
    const yelayLiteVaultAddress = contracts.vaults.WETH;
    const vaultWrapper = VaultWrapper__factory.connect(contracts.vaultWrapper.proxy, deployer);
    try {
        const tx = await vaultWrapper.wrapEthAndDeposit(yelayLiteVaultAddress, PROJECT_ID, {
            value: AMOUNT,
        });
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
