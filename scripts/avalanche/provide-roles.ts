import { ethers } from 'hardhat';
import contracts from '../../deployments/avalanche.json';
import { IYelayLiteVault__factory } from '../../typechain-types';
import { ADDRESSES, ROLES } from '../constants';

async function main() {
    const [deployer] = await ethers.getSigners();
    const assets = ['USDC', 'WETH'] as const;
    const AUTHORITY = ADDRESSES[43114].OWNER;
    const OPERATOR = ADDRESSES[43114].OPERATOR;
    for (const asset of assets) {
        const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults[asset], deployer);

        const data = await Promise.all([
            yelayLiteVault.grantRole.populateTransaction(ROLES.STRATEGY_AUTHORITY, AUTHORITY),
            yelayLiteVault.grantRole.populateTransaction(ROLES.PAUSER, AUTHORITY),
            yelayLiteVault.grantRole.populateTransaction(ROLES.UNPAUSER, AUTHORITY),
            yelayLiteVault.grantRole.populateTransaction(ROLES.FUNDS_OPERATOR, AUTHORITY),
            yelayLiteVault.grantRole.populateTransaction(ROLES.QUEUES_OPERATOR, AUTHORITY),

            yelayLiteVault.grantRole.populateTransaction(ROLES.FUNDS_OPERATOR, OPERATOR),
            yelayLiteVault.grantRole.populateTransaction(ROLES.QUEUES_OPERATOR, OPERATOR),
            yelayLiteVault.grantRole.populateTransaction(ROLES.PAUSER, OPERATOR),
            yelayLiteVault.grantRole.populateTransaction(ROLES.SWAP_REWARDS_OPERATOR, OPERATOR),

            yelayLiteVault.grantRole.populateTransaction(
                ROLES.STRATEGY_AUTHORITY,
                deployer.address,
            ),
            yelayLiteVault.grantRole.populateTransaction(ROLES.FUNDS_OPERATOR, deployer.address),
            yelayLiteVault.grantRole.populateTransaction(ROLES.QUEUES_OPERATOR, deployer.address),
        ]);

        await yelayLiteVault.multicall(data.map((d) => d.data));
    }
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
