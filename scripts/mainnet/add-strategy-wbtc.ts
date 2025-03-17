import { ethers } from 'hardhat';
import contracts from '../../deployments/mainnet.json';
import { IYelayLiteVault__factory } from '../../typechain-types';

async function main() {
    const asset = 'WBTC';
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults[asset], deployer);

    const data = await Promise.all([
        yelayLiteVault.addStrategy.populateTransaction({
            name: ethers.encodeBytes32String('pendle-wbtc'),
            adapter: contracts.strategies.morphoVaults[asset]['pendle-wbtc'],
            supplement: '0x',
        }),
        yelayLiteVault.addStrategy.populateTransaction({
            name: ethers.encodeBytes32String('gauntlet-wbtc-core'),
            adapter: contracts.strategies.morphoVaults[asset]['gauntlet-wbtc-core'],
            supplement: '0x',
        }),
        yelayLiteVault.activateStrategy.populateTransaction(1, [0], [0]),
        yelayLiteVault.approveStrategy.populateTransaction(0, ethers.MaxUint256),
        yelayLiteVault.approveStrategy.populateTransaction(1, ethers.MaxUint256),
    ]);

    await yelayLiteVault.multicall(data.map((d) => d.data));
}

main()
    .then(() => {
        console.log('Ready');
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
