import { artifacts, ethers } from 'hardhat';
import path from 'path';
import {
    IAccessFacet__factory,
    IClientsFacet__factory,
    IFundsFacet__factory,
    IManagementFacet__factory,
    IOwnerFacet__factory,
    IYelayLiteVault,
    IYelayLiteVault__factory,
    Swapper__factory,
    VaultWrapper,
    VaultWrapper__factory,
} from '../../typechain-types';
import { ADDRESSES, IMPLEMENTATION_STORAGE_SLOT, ROLES } from '../constants';
import {
    getAccessFacetSelectors,
    getClientFacetSelectors,
    getFundsFacetSelectors,
    getManagementFacetSelectors,
    getOwnerFacetSelectors,
    getRoleMembers,
} from './getters';
import { warning } from './common';

export const checkFacets = async (
    yelayLiteVault: IYelayLiteVault,
    facet: string,
    selectorToFunctionNameMap: Record<string, string>,
) => {
    const facets: string[] = [];
    const selectors = Object.keys(selectorToFunctionNameMap);
    for (const s of selectors) {
        const f = await yelayLiteVault.selectorToFacet(s);
        facets.push(f);
    }
    facets.forEach((f, i) => {
        if (facet.toLowerCase() !== f.toLowerCase()) {
            warning(
                `Selector ${selectorToFunctionNameMap[selectors[i]]} for ${facet} is not correctly set`,
            );
        }
    });
};

export const checkImplementation = async (
    provider: typeof ethers.provider,
    proxy: string,
    implementation: string,
) => {
    const actualImplementation = await provider
        .getStorage(proxy, IMPLEMENTATION_STORAGE_SLOT)
        .then((r) => ethers.dataSlice(r, 12));
    if (implementation.toLowerCase() !== actualImplementation.toLowerCase()) {
        console.error(`Implementation doesn't match for: ${proxy} !`);
    }
};

export const checkSwapper = async (contract: IYelayLiteVault | VaultWrapper, swapper: string) => {
    const actualSwapper = await contract.swapper();
    if (actualSwapper.toLowerCase() !== swapper.toLowerCase()) {
        console.error(`Swapper doesn't match for ${await contract.getAddress()}`);
    }
};

export const checkSetup = async (contracts: any, provider: typeof ethers.provider) => {
    for (const [asset, address] of Object.entries(contracts.vaults)) {
        console.log(`Working on ${asset}:${address} vault....`);
        console.log('');
        const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults[asset], provider);

        console.log('Checking selectors...');
        await checkFacets(yelayLiteVault, contracts.accessFacet, getAccessFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.ownerFacet, getOwnerFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.fundsFacet, getFundsFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.managementFacet, getManagementFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.clientsFacet, getClientFacetSelectors());

        console.log('');

        console.log(`Getting addresses...`);
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
        console.log('Checking swapper on vault....');
        console.log('');

        await checkSwapper(yelayLiteVault, contracts.swapper.proxy);
        console.log('');
    }

    console.log(`Working on swapper and vaultWrapper...`);
    console.log('');

    await Swapper__factory.connect(contracts.swapper.proxy, provider)
        .owner()
        .then((r) => console.log(`Swapper owner: ${r}`));
    await VaultWrapper__factory.connect(contracts.vaultWrapper.proxy, provider)
        .owner()
        .then((r) => console.log(`VaultWrapper owner: ${r}`));

    console.log('');
    console.log('Checking swapper implementation....');
    console.log('');

    await checkImplementation(provider, contracts.swapper.proxy, contracts.swapper.implementation);

    console.log('');
    console.log('Checking vaultWrapper implementation....');
    console.log('');

    await checkImplementation(
        provider,
        contracts.vaultWrapper.proxy,
        contracts.vaultWrapper.implementation,
    );

    console.log('');
    console.log('Checking swapper on vaultWrapper....');
    console.log('');

    await checkSwapper(
        VaultWrapper__factory.connect(contracts.vaultWrapper.proxy, provider),
        contracts.swapper.proxy,
    );

    console.log('');
    console.log('Checking one inch whitelisting on swapper...');
    console.log('');
    await Swapper__factory.connect(contracts.swapper.proxy, provider)
        .exchangeAllowlist(ADDRESSES.BASE.ONE_INCH_ROUTER_V6)
        .then((r) => {
            if (!r) {
                console.error(`one inch doesn't allowed`);
            }
        });
};

async function compareBytecode(contractName: string, deployedAddress: string) {
    const artifact = await artifacts.readArtifact(contractName);
    const localBytecode = artifact.deployedBytecode;
    const onChainBytecode = await ethers.provider.getCode(deployedAddress);
    if (localBytecode !== onChainBytecode) {
        warning(`${deployedAddress} is not the latest ${contractName}!`);
    }
}

export const logRoleMembers = async (
    yelayLiteVault: IYelayLiteVault,
    roleName: keyof typeof ROLES,
) => {
    const r = await getRoleMembers(yelayLiteVault, ROLES[roleName]);
    console.log(`${roleName}: ${r.join(', ')}`);
};
