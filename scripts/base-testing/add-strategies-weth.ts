import { ethers } from 'hardhat';
import strategies from '../../deployments/base-strategies.json';
import contracts from '../../deployments/base-testing.json';
import { IPool__factory, IYelayLiteVault__factory } from '../../typechain-types';
import { AAVE_V3_POOL_BASE, WETH_ADDRESS_BASE } from './constants';

async function main() {
    const [deployer] = await ethers.getSigners();
    const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults.weth, deployer);
    const data: string[] = [];
    await yelayLiteVault.addStrategy
        .populateTransaction(
            {
                adapter: strategies['aave-v3'],
                supplement: new ethers.AbiCoder().encode(
                    ['address', 'address'],
                    [
                        WETH_ADDRESS_BASE,
                        await IPool__factory.connect(AAVE_V3_POOL_BASE, deployer)
                            .getReserveData(WETH_ADDRESS_BASE)
                            .then((r) => r.aTokenAddress),
                    ],
                ),
                name: ethers.encodeBytes32String('AAVE-V3-WETH'),
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
                        WETH_ADDRESS_BASE,
                        '0x86021ffe2f778ed8aacecdf3dae2cdef77dbfa5e133b018cca16c52ceab58996',
                    ],
                ),
                name: ethers.encodeBytes32String('MORPHO-ezETH-WETH'),
            },
            [0, 1],
            [0, 1],
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
