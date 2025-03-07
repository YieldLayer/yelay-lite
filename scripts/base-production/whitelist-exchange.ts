import { ethers } from 'hardhat';
import contracts from '../../deployments/base-production.json';
import { ISwapper__factory } from '../../typechain-types';
import { ADDRESSES } from '../constants';

async function main() {
    const [deployer] = await ethers.getSigners();
    const swapper = ISwapper__factory.connect(contracts.swapper.proxy, deployer);
    await swapper.updateExchangeAllowlist([
        { exchange: ADDRESSES.BASE.ONE_INCH_ROUTER_V6, allowed: true },
    ]);
}

main();
