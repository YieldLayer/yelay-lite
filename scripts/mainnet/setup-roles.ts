import { ethers } from 'hardhat';
import contracts from '../../deployments/mainnet.json';
import { IYelayLiteVault__factory } from '../../typechain-types';
import { ADDRESSES, ROLES } from '../constants';

async function main() {
    const [deployer] = await ethers.getSigners();

    for (const vaultAddress of Object.values(contracts.vaults)) {
        const yelayLiteVault = IYelayLiteVault__factory.connect(vaultAddress, deployer);
        const data = await Promise.all([
            // OWNER
            yelayLiteVault.grantRole.populateTransaction(
                ROLES.STRATEGY_AUTHORITY,
                ADDRESSES.MAINNET.OWNER,
            ),
            yelayLiteVault.grantRole.populateTransaction(ROLES.PAUSER, ADDRESSES.MAINNET.OWNER),
            yelayLiteVault.grantRole.populateTransaction(ROLES.UNPAUSER, ADDRESSES.MAINNET.OWNER),
            yelayLiteVault.grantRole.populateTransaction(
                ROLES.QUEUES_OPERATOR,
                ADDRESSES.MAINNET.OWNER,
            ),

            // OPERATOR
            yelayLiteVault.grantRole.populateTransaction(
                ROLES.FUNDS_OPERATOR,
                ADDRESSES.MAINNET.OPERATOR,
            ),
            yelayLiteVault.grantRole.populateTransaction(
                ROLES.QUEUES_OPERATOR,
                ADDRESSES.MAINNET.OPERATOR,
            ),
            yelayLiteVault.grantRole.populateTransaction(ROLES.PAUSER, ADDRESSES.MAINNET.OPERATOR),
            yelayLiteVault.grantRole.populateTransaction(
                ROLES.SWAP_REWARDS_OPERATOR,
                ADDRESSES.MAINNET.OPERATOR,
            ),

            // DEPLOYER FOR INITIAL SETUP
            yelayLiteVault.grantRole.populateTransaction(
                ROLES.STRATEGY_AUTHORITY,
                deployer.address,
            ),
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
