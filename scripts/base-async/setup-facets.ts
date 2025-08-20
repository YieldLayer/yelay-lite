import { ethers } from 'hardhat';
import contracts from '../../deployments/base-async.json';
import { IYelayLiteVaultAsync__factory } from '../../typechain-types';
import {
    getAccessFacetSelectors,
    getAsyncFundsFacetSelectors,
    getCCTPV2FacetSelectors,
    getClientFacetSelectors,
    getManagementFacetSelectors,
} from '../utils/getters';

async function main() {
    const [deployer] = await ethers.getSigners();
    const vault = IYelayLiteVaultAsync__factory.connect(contracts.vaults.USDC, deployer);
    return vault.setSelectorToFacets([
        {
            facet: contracts.asyncFundsFacet,
            selectors: Object.keys(getAsyncFundsFacetSelectors()),
        },
        {
            facet: contracts.managementFacet,
            selectors: Object.keys(getManagementFacetSelectors()),
        },
        {
            facet: contracts.accessFacet,
            selectors: Object.keys(getAccessFacetSelectors()),
        },
        {
            facet: contracts.clientsFacet,
            selectors: Object.keys(getClientFacetSelectors()),
        },
        {
            facet: contracts.cctpV2Facet,
            selectors: Object.keys(getCCTPV2FacetSelectors()),
        },
    ]);
}

main();
