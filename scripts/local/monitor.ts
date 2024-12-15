import { ethers } from 'hardhat';
import contracts from '../../deployments/local.json';
import {
    ERC20__factory,
    FundsFacet__factory,
    IYelayLiteVault__factory,
} from '../../typechain-types';
import { USDC_ADDRESS } from '../constants';

async function main() {
    const [, yieldExtractor, user1, user2, user3] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(
        contracts.yelayLiteVault,
        ethers.provider,
    );
    const usdc = ERC20__factory.connect(USDC_ADDRESS, ethers.provider);

    const users = [
        { name: 'yieldExtractor', address: yieldExtractor.address },
        { name: 'user1', address: user1.address },
        { name: 'user2', address: user2.address },
        { name: 'user3', address: user3.address },
    ];

    console.log('============');
    console.log(`Vault info`);
    await yelayLiteVault['totalSupply()']().then((r) =>
        console.log(`Total supply: ${ethers.formatUnits(r, 6)}`),
    );
    await yelayLiteVault['totalSupply(uint256)'](0).then((r) =>
        console.log(`Total supply 0: ${ethers.formatUnits(r, 6)}`),
    );
    await yelayLiteVault['totalSupply(uint256)'](1).then((r) =>
        console.log(`Total supply 1: ${ethers.formatUnits(r, 6)}`),
    );
    await yelayLiteVault
        .totalAssets()
        .then((r) => console.log(`Total assets: ${ethers.formatUnits(r, 6)}`));
    await yelayLiteVault
        .lastTotalAssets()
        .then((r) => console.log(`Last total assets: ${ethers.formatUnits(r, 6)}`));
    await yelayLiteVault
        .queryFilter(
            FundsFacet__factory.connect(contracts.yelayLiteVault).filters['AccrueInterest'],
        )
        .then((r) => console.log(r.length));
    console.log('============');

    for (let i = 0; i < users.length; i++) {
        const user = users[i];
        const shareBalance = await yelayLiteVault.balanceOf(
            user.address,
            user.name === 'yieldExtractor' ? 0 : 1,
        );
        const usdcBalance = await usdc.balanceOf(user.address);
        console.log(user.name + ' - ' + user.address);
        console.log(`Shares: ${ethers.formatUnits(shareBalance, 6)}`);
        console.log(`USDC: ${ethers.formatUnits(usdcBalance, 6)}`);
        console.log('============');
    }
}

main();
