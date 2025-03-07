import { ethers } from 'hardhat';
import contracts from '../../deployments/base-production.json';
import {
    ERC20__factory,
    IYelayLiteVault__factory,
    LibErrors__factory,
} from '../../typechain-types';

const PROJECT_ID = 1;
const AMOUNT = 20;

async function main() {
    const [deployer] = await ethers.getSigners();
    const yelayLiteVaultAddress = contracts.vaults.USDC;
    const yelayLiteVault = IYelayLiteVault__factory.connect(yelayLiteVaultAddress, ethers.provider);
    const underlyingAsset = await yelayLiteVault.underlyingAsset();
    const token = ERC20__factory.connect(underlyingAsset, deployer);
    const decimals = await token.decimals();
    const amount = ethers.parseUnits(String(AMOUNT), decimals);
    const allowance = await token.allowance(deployer.address, yelayLiteVaultAddress);
    if (allowance === 0n) {
        await token.approve(yelayLiteVaultAddress, ethers.MaxUint256).then((tx) => tx.wait(10));
    }
    try {
        const tx = await yelayLiteVault
            .connect(deployer)
            .deposit(amount, PROJECT_ID, deployer.address);
        const receipt = await tx.wait(1);
        if (receipt?.status === 1) {
            console.log('Tx successful');
        } else {
            console.log('Tx failed');
        }
    } catch (error: any) {
        const parsedError = LibErrors__factory.createInterface().parseError(error.data);
        if (parsedError) {
            console.error(`Error: ${parsedError.name}`);
        } else {
            console.error(`Error: ${error}`);
            throw new Error('Failed call');
        }
    }
}

main()
    .then(() => {
        console.log('Done');
    })
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
