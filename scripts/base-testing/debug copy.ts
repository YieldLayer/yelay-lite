import { ethers } from 'hardhat';
import contracts from '../../deployments/base-production.json';
import { IFundsFacet__factory, IYelayLiteVault__factory } from '../../typechain-types';

async function main() {
    // const [deployer] = await ethers.getSigners();
    // const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults.WETH, deployer);
    // const i = IFundsFacet__factory.createInterface();
    // await yelayLiteVault.setYieldExtractor('0xC5F749e00d5C67646a1B18DB36F8BBec80B96EB9');
    // await yelayLiteVault.setSelectorToFacets([
    //     {
    //         facet: contracts.fundsFacet,
    //         selectors: [
    //             i.getFunction('totalSupply()').selector,
    //             i.getFunction('totalSupply(uint256)').selector,
    //             i.getFunction('lastTotalAssets').selector,
    //             i.getFunction('lastTotalAssetsTimestamp').selector,
    //             i.getFunction('lastTotalAssetsUpdateInterval').selector,
    //             i.getFunction('setLastTotalAssetsUpdateInterval').selector,
    //             i.getFunction('underlyingBalance').selector,
    //             i.getFunction('underlyingAsset').selector,
    //             i.getFunction('yieldExtractor').selector,
    //             i.getFunction('swapper').selector,
    //             i.getFunction('totalAssets').selector,
    //             i.getFunction('strategyAssets').selector,
    //             i.getFunction('strategyRewards').selector,
    //             i.getFunction('deposit').selector,
    //             i.getFunction('redeem').selector,
    //             i.getFunction('migratePosition').selector,
    //             i.getFunction('managedDeposit').selector,
    //             i.getFunction('managedWithdraw').selector,
    //             i.getFunction('reallocate').selector,
    //             i.getFunction('swapRewards').selector,
    //             i.getFunction('accrueFee').selector,
    //             i.getFunction('claimStrategyRewards').selector,
    //             i.getFunction('balanceOf').selector,
    //             i.getFunction('uri').selector,
    //             i.getFunction('setYieldExtractor').selector,
    //         ],
    //     },
    // ]);
    // const fundsFacet = await ethers
    //     .getContractFactory('FundsFacet', deployer)
    //     .then((f) => f.deploy(contracts.swapper.proxy))
    //     .then((r) => r.waitForDeployment())
    //     .then((r) => r.getAddress());
    // contracts.fundsFacet = fundsFacet;
    // fs.writeFileSync('./deployments/base-testing.json', JSON.stringify(contracts, null, 4) + '\n');
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
