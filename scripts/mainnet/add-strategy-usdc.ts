import { ethers } from 'hardhat';
import contracts from '../../deployments/mainnet.json';
import { IPool__factory, IYelayLiteVault__factory } from '../../typechain-types';
import { ADDRESSES } from '../constants';

async function main() {
    const asset = 'USDC';
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults[asset], deployer);

    const aToken = await IPool__factory.connect(ADDRESSES[1].AAVE_V3_POOL, deployer)
        .getReserveData(ADDRESSES[1][asset])
        .then((r) => r.aTokenAddress);

    const data = await Promise.all([
        yelayLiteVault.addStrategy.populateTransaction({
            name: ethers.encodeBytes32String('aave-v3'),
            adapter: contracts.strategies.aaveV3,
            supplement: new ethers.AbiCoder().encode(
                ['address', 'address'],
                [ADDRESSES[1][asset], aToken],
            ),
        }),
        yelayLiteVault.addStrategy.populateTransaction({
            name: ethers.encodeBytes32String('gauntlet-usdc-core'),
            adapter: contracts.strategies.morphoVaults[asset]['gauntlet-usdc-core'],
            supplement: '0x',
        }),
        yelayLiteVault.addStrategy.populateTransaction({
            name: ethers.encodeBytes32String('steakhouse-usdc'),
            adapter: contracts.strategies.morphoVaults[asset]['steakhouse-usdc'],
            supplement: '0x',
        }),
        yelayLiteVault.activateStrategy.populateTransaction(2, [0], [0]),
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
