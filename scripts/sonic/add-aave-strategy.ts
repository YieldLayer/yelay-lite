import { ethers } from 'hardhat';
import contracts from '../../deployments/sonic.json';
import { IPool__factory, IYelayLiteVault__factory } from '../../typechain-types';
import { ADDRESSES } from '../constants';

async function main() {
    const chainId = 146;
    const asset = 'WS';
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults[asset], deployer);

    const aToken = await IPool__factory.connect(ADDRESSES[chainId].AAVE_V3_POOL, deployer)
        .getReserveData(ADDRESSES[chainId][asset])
        .then((r) => r.aTokenAddress);

    const data = await Promise.all([
        yelayLiteVault.addStrategy.populateTransaction({
            name: ethers.encodeBytes32String('aave-v3'),
            adapter: contracts.strategies.aaveV3,
            supplement: new ethers.AbiCoder().encode(
                ['address', 'address'],
                [ADDRESSES[chainId][asset], aToken],
            ),
        }),
        yelayLiteVault.activateStrategy.populateTransaction(0, [0], [0]),
        yelayLiteVault.approveStrategy.populateTransaction(0, ethers.MaxUint256),
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
