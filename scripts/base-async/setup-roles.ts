import { ethers } from 'hardhat';
import contracts from '../../deployments/base-async.json';
import { IYelayLiteVault__factory } from '../../typechain-types';
import { ROLES } from '../constants';

async function main() {
    const [deployer] = await ethers.getSigners();

    const yelayLiteVault = IYelayLiteVault__factory.connect(
        contracts.vaults['USDC-satellite'],
        deployer,
    );
    const data = await Promise.all([
        yelayLiteVault.grantRole.populateTransaction(ROLES.STRATEGY_AUTHORITY, deployer.address),
        yelayLiteVault.grantRole.populateTransaction(ROLES.QUEUES_OPERATOR, deployer.address),
        yelayLiteVault.grantRole.populateTransaction(ROLES.FUNDS_OPERATOR, deployer.address),
        yelayLiteVault.grantRole.populateTransaction(ROLES.YIELD_PUBLISHER, deployer.address),
    ]);

    await yelayLiteVault.multicall(data.map((d) => d.data));
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
