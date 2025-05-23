import { ethers } from 'hardhat';
import contracts from '../../deployments/base-production.json';
import { IPool__factory, IYelayLiteVault__factory } from '../../typechain-types';
import { ADDRESSES } from '../constants';

async function main() {
    const asset = 'WETH';
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults[asset], deployer);

    const aToken = await IPool__factory.connect(ADDRESSES[8453].AAVE_V3_POOL, deployer)
        .getReserveData(ADDRESSES[8453][asset])
        .then((r) => r.aTokenAddress);

    const data = await Promise.all([
        yelayLiteVault.addStrategy.populateTransaction({
            name: ethers.encodeBytes32String('aave-v3'),
            adapter: contracts.strategies.aaveV3,
            supplement: new ethers.AbiCoder().encode(
                ['address', 'address'],
                [ADDRESSES[8453][asset], aToken],
            ),
        }),
        yelayLiteVault.addStrategy.populateTransaction({
            name: ethers.encodeBytes32String('ionic-ecosystem-weth'),
            adapter: contracts.strategies.morphoVaults[asset]['ionic-ecosystem-weth'],
            supplement: '0x',
        }),
        yelayLiteVault.addStrategy.populateTransaction({
            name: ethers.encodeBytes32String('moonwell-flagship-eth'),
            adapter: contracts.strategies.morphoVaults[asset]['moonwell-flagship-eth'],
            supplement: '0x',
        }),
        yelayLiteVault.activateStrategy.populateTransaction(1, [0], [0]),
        yelayLiteVault.approveStrategy.populateTransaction(0, ethers.MaxUint256),
        yelayLiteVault.approveStrategy.populateTransaction(1, ethers.MaxUint256),
        yelayLiteVault.approveStrategy.populateTransaction(2, ethers.MaxUint256),
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
