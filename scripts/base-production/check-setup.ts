import { ethers } from 'hardhat';
import contracts from '../../deployments/base-production.json';
import {
    IYelayLiteVault__factory,
    Swapper__factory,
    VaultWrapper__factory,
} from '../../typechain-types';
import { ADDRESSES } from '../constants';
import {
    checkFacets,
    checkImplementation,
    checkSwapper,
    getAccessFacetSelectors,
    getClientFacetSelectors,
    getFundsFacetSelectors,
    getManagementFacetSelectors,
    getOwnerFacetSelectors,
    logRoleMembers,
} from '../utils';

async function main() {
    const asset = 'WETH';
    const yelayLiteVault = IYelayLiteVault__factory.connect(
        contracts.vaults[asset],
        ethers.provider,
    );

    console.log('Checking selectors...');
    await checkFacets(yelayLiteVault, contracts.accessFacet, getAccessFacetSelectors());
    await checkFacets(yelayLiteVault, contracts.ownerFacet, getOwnerFacetSelectors());
    await checkFacets(yelayLiteVault, contracts.fundsFacet, getFundsFacetSelectors());
    await checkFacets(yelayLiteVault, contracts.managementFacet, getManagementFacetSelectors());
    await checkFacets(yelayLiteVault, contracts.clientsFacet, getClientFacetSelectors());

    console.log('');

    console.log(`Getting addresses...`);

    await Swapper__factory.connect(contracts.swapper.proxy, ethers.provider)
        .owner()
        .then((r) => console.log(`Swapper owner: ${r}`));
    await VaultWrapper__factory.connect(contracts.vaultWrapper.proxy, ethers.provider)
        .owner()
        .then((r) => console.log(`VaultWrapper owner: ${r}`));
    await yelayLiteVault.owner().then((r) => console.log(`Vault owner: ${r}`));
    await yelayLiteVault.owner().then((r) => console.log(`Vault owner: ${r}`));
    await yelayLiteVault.yieldExtractor().then((r) => console.log(`YieldExtractor: ${r}`));
    await yelayLiteVault.underlyingAsset().then((r) => console.log(`Underlying asset: ${r}`));

    console.log('');
    console.log('Logging role members....');
    console.log('');

    await logRoleMembers(yelayLiteVault, 'STRATEGY_AUTHORITY');
    console.log('');
    await logRoleMembers(yelayLiteVault, 'QUEUES_OPERATOR');
    console.log('');
    await logRoleMembers(yelayLiteVault, 'FUNDS_OPERATOR');
    console.log('');
    await logRoleMembers(yelayLiteVault, 'SWAP_REWARDS_OPERATOR');
    console.log('');
    await logRoleMembers(yelayLiteVault, 'PAUSER');
    console.log('');
    await logRoleMembers(yelayLiteVault, 'UNPAUSER');

    console.log('');
    console.log('Checking swapper implementation....');
    console.log('');

    await checkImplementation(
        ethers.provider,
        contracts.swapper.proxy,
        contracts.swapper.implementation,
    );

    console.log('');
    console.log('Checking vaultWrapper implementation....');
    console.log('');

    await checkImplementation(
        ethers.provider,
        contracts.vaultWrapper.proxy,
        contracts.vaultWrapper.implementation,
    );

    console.log('');
    console.log('Checking swapper on vault and vaultWrapper....');
    console.log('');

    await checkSwapper(yelayLiteVault, contracts.swapper.proxy);
    await checkSwapper(
        VaultWrapper__factory.connect(contracts.vaultWrapper.proxy, ethers.provider),
        contracts.swapper.proxy,
    );

    console.log('');
    console.log('Checking one inch whitelisting on swapper...');
    console.log('');
    await Swapper__factory.connect(contracts.swapper.proxy, ethers.provider)
        .exchangeAllowlist(ADDRESSES.BASE.ONE_INCH_ROUTER_V6)
        .then((r) => {
            if (!r) {
                console.error(`one inch doesn't allowed`);
            }
        });
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
