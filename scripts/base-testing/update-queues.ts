import { ethers } from 'hardhat';
import contracts from '../../deployments/base-testing.json';
import { IYelayLiteVault__factory } from '../../typechain-types';

async function main() {
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.yelayLiteVault, deployer);
    const data: string[] = [];
    await yelayLiteVault.updateDepositQueue.populateTransaction([0]).then((tx) => {
        data.push(tx.data);
    });
    await yelayLiteVault.updateWithdrawQueue.populateTransaction([0]).then((tx) => {
        data.push(tx.data);
    });
    await yelayLiteVault.multicall(data);
}

main();
