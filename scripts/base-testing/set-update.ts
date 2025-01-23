import { FundsFacet__factory } from './../../typechain-types/factories/src/facets/FundsFacet__factory';
import { ethers } from 'hardhat';
import contracts from '../../deployments/base-testing.json';
import { IYelayLiteVault__factory } from '../../typechain-types';

async function main() {
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults.weth, deployer);
    const data: string[] = [];
    await yelayLiteVault.setSelectorToFacets
        .populateTransaction([
            {
                facet: contracts.fundsFacet,
                selectors: [
                    FundsFacet__factory.createInterface().getFunction(
                        'setLastTotalAssetsUpdateInterval',
                    ).selector,
                ],
            },
        ])
        .then((tx) => data.push(tx.data));
    await yelayLiteVault.setLastTotalAssetsUpdateInterval
        .populateTransaction(5 * 60)
        .then((tx) => data.push(tx.data));
    await yelayLiteVault.multicall(data);
}

main();
