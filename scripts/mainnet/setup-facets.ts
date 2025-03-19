import { ethers } from 'hardhat';
import contracts from '../../deployments/mainnet.json';
import { IYelayLiteVault__factory } from '../../typechain-types';
import { prepareSetSelectorFacets } from '../utils/deploy';

async function main() {
    const [deployer] = await ethers.getSigners();

    for (const vaultAddress of Object.values(contracts.vaults)) {
        const vault = IYelayLiteVault__factory.connect(vaultAddress, deployer);
        const populatedTx = await prepareSetSelectorFacets({
            yelayLiteVault: vault,
            fundsFacet: contracts.fundsFacet,
            clientsFacet: contracts.clientsFacet,
            managementFacet: contracts.managementFacet,
            accessFacet: contracts.accessFacet,
        });
        await vault.multicall([populatedTx.data]);
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
