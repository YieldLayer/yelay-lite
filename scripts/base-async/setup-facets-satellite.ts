import { ethers } from 'hardhat';
import contracts from '../../deployments/base-async.json';
import { IYelayLiteVaultAsync__factory } from '../../typechain-types';
import {
    getAccessFacetSelectors,
    getCCTPV2FacetSelectors,
    getFundsFacetSatelliteSelectors,
    getManagementFacetSelectors,
} from '../utils/getters';

async function main() {
    const [deployer] = await ethers.getSigners();
    const vault = IYelayLiteVaultAsync__factory.connect(
        contracts.vaults['USDC-satellite'],
        deployer,
    );
    return vault.setSelectorToFacets([
        {
            facet: contracts.managementFacet,
            selectors: Object.keys(getManagementFacetSelectors()),
        },
        {
            facet: contracts.accessFacet,
            selectors: Object.keys(getAccessFacetSelectors()),
        },
        {
            facet: contracts.cctpV2Facet,
            selectors: Object.keys(getCCTPV2FacetSelectors()),
        },
        {
            facet: contracts.fundsFacet,
            selectors: Object.keys(getFundsFacetSatelliteSelectors()),
        },
    ]);
}

main();
