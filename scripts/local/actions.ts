import type { ContractTransactionResponse, Signer } from 'ethers';
import type { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    ERC20__factory,
    IYelayLiteVault,
    IYelayLiteVault__factory,
    LibErrors__factory,
} from '../../typechain-types';

type Args = {
    userIndex: number;
    amount: number;
    projectId: number;
};

type MigrationArgs = {
    userIndex: number;
    amount: number;
    fromProjectId: number;
    toProjectId: number;
};

const validateNetwork = (hre: HardhatRuntimeEnvironment) => {
    if (hre.network.name !== 'local') {
        throw new Error('Not local network');
    }
};

const getUser = async (args: { userIndex: number }, hre: HardhatRuntimeEnvironment) => {
    const signers = await hre.ethers.getSigners();
    const user = signers[args.userIndex + 1];
    return user;
};

const getYelayLiteVault = async (hre: HardhatRuntimeEnvironment) => {
    const contractsFile = (await import('../../deployments/local.json')).default;
    return IYelayLiteVault__factory.connect(contractsFile.yelayLiteVault, hre.ethers.provider);
};

const checkTxSuccess = async (tx: ContractTransactionResponse) => {
    const receipt = await tx.wait(1);
    if (receipt?.status === 1) {
        console.log('Tx successful');
    } else {
        console.log('Tx failed');
    }
};

const action =
    (
        fn: (
            yelayLiteVault: IYelayLiteVault,
            user: Signer,
            amount: bigint,
            projectId: number,
        ) => Promise<ContractTransactionResponse>,
    ) =>
    async (args: Args, hre: HardhatRuntimeEnvironment) => {
        validateNetwork(hre);
        const user = await getUser(args, hre);
        const yelayLiteVault = await getYelayLiteVault(hre);
        const underlyingAsset = await yelayLiteVault.underlyingAsset();
        const decimals = await ERC20__factory.connect(
            underlyingAsset,
            hre.ethers.provider,
        ).decimals();
        const amount = hre.ethers.parseUnits(String(args.amount), decimals);
        try {
            const tx = await fn(yelayLiteVault, user, amount, args.projectId);
            await checkTxSuccess(tx);
        } catch (error: any) {
            const parsedError = LibErrors__factory.createInterface().parseError(error.data);
            if (parsedError) {
                console.error(`Error: ${parsedError.name}`);
            } else {
                console.error(`Error: ${error}`);
                throw new Error('Failed call');
            }
        }
    };

export const deposit = action(
    async (yelayLiteVault: IYelayLiteVault, user: Signer, amount: bigint, projectId: number) => {
        return await yelayLiteVault
            .connect(user)
            .deposit(amount, projectId, await user.getAddress());
    },
);

export const redeem = action(
    async (yelayLiteVault: IYelayLiteVault, user: Signer, amount: bigint, projectId: number) => {
        return await yelayLiteVault
            .connect(user)
            .redeem(amount, projectId, await user.getAddress());
    },
);

export const migrate = async (args: MigrationArgs, hre: HardhatRuntimeEnvironment) => {
    validateNetwork(hre);
    const user = await getUser(args, hre);
    const yelayLiteVault = await getYelayLiteVault(hre);
    const underlyingAsset = await yelayLiteVault.underlyingAsset();
    const decimals = await ERC20__factory.connect(underlyingAsset, hre.ethers.provider).decimals();
    const amount = hre.ethers.parseUnits(String(args.amount), decimals);

    try {
        const tx = await yelayLiteVault
            .connect(user)
            .migratePosition(
                args.fromProjectId.toString(),
                args.toProjectId.toString(),
                amount.toString(),
            );
        await checkTxSuccess(tx);
    } catch (error: any) {
        const parsedError = LibErrors__factory.createInterface().parseError(error.data);
        if (parsedError) {
            console.error(parsedError);
        } else {
            console.error(`Error: ${error}`);
            throw new Error('Failed call');
        }
    }
};
