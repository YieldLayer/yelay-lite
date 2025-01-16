import { ethers } from 'hardhat';
import strategies from '../../deployments/base-strategies.json';
import contracts from '../../deployments/base-testing.json';
import { IPool__factory, IYelayLiteVault__factory } from '../../typechain-types';
import { AAVE_V3_POOL_BASE, USDC_ADDRESS_BASE } from './constants';

async function main() {
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.yelayLiteVault, deployer);
    const data: string[] = [];
    await yelayLiteVault.addStrategy
        .populateTransaction(
            {
                adapter: strategies['aave-v3'],
                supplement: new ethers.AbiCoder().encode(
                    ['address', 'address'],
                    [
                        USDC_ADDRESS_BASE,
                        await IPool__factory.connect(AAVE_V3_POOL_BASE, deployer)
                            .getReserveData(USDC_ADDRESS_BASE)
                            .then((r) => r.aTokenAddress),
                    ],
                ),
                name: ethers.encodeBytes32String('AAVE-V3-USDC'),
            },
            [],
            [],
        )
        .then((tx) => {
            data.push(tx.data);
        });
    await yelayLiteVault.addStrategy
        .populateTransaction(
            {
                adapter: strategies['morpho-blue'],
                supplement: new ethers.AbiCoder().encode(
                    ['address', 'bytes32'],
                    [
                        USDC_ADDRESS_BASE,
                        '0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836',
                    ],
                ),
                name: ethers.encodeBytes32String('MORPHO-cbBTC-USDC'),
            },
            [],
            [],
        )
        .then((tx) => {
            data.push(tx.data);
        });
    await yelayLiteVault.approveStrategy.populateTransaction(0, ethers.MaxUint256).then((tx) => {
        data.push(tx.data);
    });
    await yelayLiteVault.approveStrategy.populateTransaction(1, ethers.MaxUint256).then((tx) => {
        data.push(tx.data);
    });

    await yelayLiteVault.multicall(data);
}

main();
