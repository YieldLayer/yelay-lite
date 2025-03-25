import { ethers } from 'hardhat';
import { isDeepStrictEqual } from 'node:util';
import {
    DepositLockPlugin__factory,
    IYelayLiteVault,
    IYelayLiteVault__factory,
    Swapper__factory,
    VaultWrapper,
    VaultWrapper__factory,
} from '../../typechain-types';
import { ExpectedAddresses, IMPLEMENTATION_STORAGE_SLOT, ROLES } from '../constants';
import { warning } from './common';
import {
    getAccessFacetSelectors,
    getClientFacetSelectors,
    getFundsFacetSelectors,
    getManagementFacetSelectors,
    getOwnerFacetSelectors,
    getRoleMembers,
} from './getters';

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
        warning(`Implementation doesn't match for: ${proxy} !`);
    }
};

export const checkSwapper = async (contract: IYelayLiteVault | VaultWrapper, swapper: string) => {
    const actualSwapper = await contract.swapper();
    if (actualSwapper.toLowerCase() !== swapper.toLowerCase()) {
        warning(`Swapper doesn't match for ${await contract.getAddress()}`);
    }
};

export const checkSetup = async (
    contracts: any,
    provider: typeof ethers.provider,
    {
        owner,
        operator,
        yieldExtractor,
        oneInchRouter,
        strategyAuthority,
        fundsOperator,
        queueOperator,
        swapRewardsOperator,
        pauser,
        unpauser,
    }: ExpectedAddresses,
) => {
    console.log(`Working on swapper, vaultWrapper, depositLockPlugin...`);
    console.log('');

    await Swapper__factory.connect(contracts.swapper.proxy, provider)
        .owner()
        .then((swapperOwner) => {
            if (swapperOwner.toLowerCase() !== owner.toLowerCase()) {
                warning(`Swapper owner mismatch! Expected: ${owner}. Actual: ${swapperOwner}`);
            }
        });
    await VaultWrapper__factory.connect(contracts.vaultWrapper.proxy, provider)
        .owner()
        .then((vaultWrapperOwner) => {
            if (vaultWrapperOwner.toLowerCase() !== owner.toLowerCase()) {
                warning(
                    `VaultWrapper owner mismatch! Expected: ${owner}. Actual: ${vaultWrapperOwner}`,
                );
            }
        });
    await DepositLockPlugin__factory.connect(contracts.depositLockPlugin.proxy, provider)
        .owner()
        .then((depositLockPluginOwner) => {
            if (depositLockPluginOwner.toLowerCase() !== owner.toLowerCase()) {
                warning(
                    `DepositLockPlugin owner mismatch! Expected: ${owner}. Actual: ${depositLockPluginOwner}`,
                );
            }
        });

    await checkImplementation(provider, contracts.swapper.proxy, contracts.swapper.implementation);

    await checkImplementation(
        provider,
        contracts.vaultWrapper.proxy,
        contracts.vaultWrapper.implementation,
    );

    await checkImplementation(
        provider,
        contracts.depositLockPlugin.proxy,
        contracts.depositLockPlugin.implementation,
    );

    await checkSwapper(
        VaultWrapper__factory.connect(contracts.vaultWrapper.proxy, provider),
        contracts.swapper.proxy,
    );

    await Swapper__factory.connect(contracts.swapper.proxy, provider)
        .exchangeAllowlist(oneInchRouter)
        .then((r) => {
            if (!r) {
                warning(`one inch doesn't allowed`);
            }
        });

    for (const [asset, address] of Object.entries(contracts.vaults)) {
        console.log(`Working on ${asset}:${address} vault....`);
        console.log('');
        const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults[asset], provider);

        await checkFacets(yelayLiteVault, contracts.accessFacet, getAccessFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.ownerFacet, getOwnerFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.fundsFacet, getFundsFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.managementFacet, getManagementFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.clientsFacet, getClientFacetSelectors());

        await yelayLiteVault.owner().then((r) => {
            if (r.toLowerCase() !== owner.toLowerCase()) {
                warning(`Vault owner mismatch. Expected: ${owner}. Actual: ${r}`);
            }
        });
        await yelayLiteVault.yieldExtractor().then((r) => {
            if (r.toLowerCase() !== yieldExtractor.toLowerCase()) {
                warning(`YieldExtractor mismatch. Expected: ${owner}. Actual: ${r}`);
            }
        });

        await checkRoleMembers(yelayLiteVault, 'STRATEGY_AUTHORITY', strategyAuthority);
        await checkRoleMembers(yelayLiteVault, 'QUEUES_OPERATOR', queueOperator);
        await checkRoleMembers(yelayLiteVault, 'FUNDS_OPERATOR', fundsOperator);
        await checkRoleMembers(yelayLiteVault, 'SWAP_REWARDS_OPERATOR', swapRewardsOperator);
        await checkRoleMembers(yelayLiteVault, 'PAUSER', pauser);
        await checkRoleMembers(yelayLiteVault, 'UNPAUSER', unpauser);

        await checkSwapper(yelayLiteVault, contracts.swapper.proxy);
    }
};

export const checkRoleMembers = async (
    yelayLiteVault: IYelayLiteVault,
    roleName: keyof typeof ROLES,
    expectedMembers: string[],
) => {
    const members = await getRoleMembers(yelayLiteVault, ROLES[roleName]);
    const equal = isDeepStrictEqual(
        members
            .slice()
            .map((m) => m.toLowerCase())
            .sort(),
        expectedMembers
            .slice()
            .map((m) => m.toLowerCase())
            .sort(),
    );
    if (!equal) {
        warning(
            `Members of the role ${roleName} do not match! Expected: ${expectedMembers.join(', ')}. Actual: ${members.join(', ')}`,
        );
    }
};
