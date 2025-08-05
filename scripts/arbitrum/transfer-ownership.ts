import { ethers } from 'hardhat';
import contracts from '../../deployments/arbitrum.json';
import { IYelayLiteVault__factory } from '../../typechain-types';
import { ADDRESSES, ROLES } from '../constants';

async function main() {
    const [deployer] = await ethers.getSigners();

    for (const vaultAddress of Object.values(contracts.vaults)) {
        const yelayLiteVault = IYelayLiteVault__factory.connect(vaultAddress, deployer);
        const data = await Promise.all([
            yelayLiteVault.revokeRole.populateTransaction(
                ROLES.STRATEGY_AUTHORITY,
                deployer.address,
            ),
            yelayLiteVault.revokeRole.populateTransaction(ROLES.QUEUES_OPERATOR, deployer.address),
            yelayLiteVault.revokeRole.populateTransaction(ROLES.FUNDS_OPERATOR, deployer.address),
            yelayLiteVault.transferOwnership.populateTransaction(ADDRESSES[1].OWNER),
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
