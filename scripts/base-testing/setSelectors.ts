import { ethers } from 'hardhat';
import contracts from '../../deployments/base-testing.json';
import { IYelayLiteVault__factory } from '../../typechain-types';
import { FundsFacet__factory } from '../../typechain-types/factories/src/facets/FundsFacet__factory';

async function main() {
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults.usdc, deployer);
    const data: string[] = [];
    await yelayLiteVault.setSelectorToFacets
        .populateTransaction([
            {
                facet: contracts.fundsFacet,
                selectors: [
                    FundsFacet__factory.createInterface().getFunction('totalSupply()').selector,
                    FundsFacet__factory.createInterface().getFunction('totalSupply(uint256)')
                        .selector,
                ],
            },
        ])
        .then((tx) => data.push(tx.data));
    await yelayLiteVault.multicall(data);
}

main();
