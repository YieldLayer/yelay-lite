import type { BaseContract, Signer } from 'ethers';
import { ethers as trueEthers } from 'ethers';
import { ethers } from 'hardhat';
import {
    AccessFacet,
    ClientsFacet,
    FundsFacet,
    IYelayLiteVault,
    ManagementFacet,
    Swapper,
    TokenFacet,
    YelayLiteVaultInit,
} from '../typechain-types';

export const deployFacets = async (deployer: Signer) => {
    const ownerFacet = await ethers
        .getContractFactory('OwnerFacet', deployer)
        .then((f) => f.deploy());
    const tokenFacet = await ethers
        .getContractFactory('TokenFacet', deployer)
        .then((f) => f.deploy());
    const fundsFacet = await ethers
        .getContractFactory('FundsFacet', deployer)
        .then((f) => f.deploy());
    const managementFacet = await ethers
        .getContractFactory('ManagementFacet', deployer)
        .then((f) => f.deploy());
    const accessFacet = await ethers
        .getContractFactory('AccessFacet', deployer)
        .then((f) => f.deploy());
    const clientsFacet = await ethers
        .getContractFactory('ClientsFacet', deployer)
        .then((f) => f.deploy());
    return { ownerFacet, tokenFacet, fundsFacet, managementFacet, accessFacet, clientsFacet };
};

export const setSelectorFacets = async ({
    yelayLiteVault,
    tokenFacet,
    fundsFacet,
    managementFacet,
    accessFacet,
    clientsFacet,
}: {
    yelayLiteVault: IYelayLiteVault;
    tokenFacet: TokenFacet;
    fundsFacet: FundsFacet;
    managementFacet: ManagementFacet;
    accessFacet: AccessFacet;
    clientsFacet: ClientsFacet;
}) => {
    const tx = await yelayLiteVault.setSelectorToFacets([
        {
            facet: await tokenFacet.getAddress(),
            selectors: [
                tokenFacet.interface.getFunction('uri').selector,
                tokenFacet.interface.getFunction('balanceOf').selector,
                tokenFacet.interface.getFunction('mint').selector,
                tokenFacet.interface.getFunction('burn').selector,
                tokenFacet.interface.getFunction('burn').selector,
                tokenFacet.interface.getFunction('totalSupply()').selector,
                tokenFacet.interface.getFunction('totalSupply(uint256)').selector,
                tokenFacet.interface.getFunction('migrate').selector,
            ],
        },
        {
            facet: await fundsFacet.getAddress(),
            selectors: [
                fundsFacet.interface.getFunction('deposit').selector,
                fundsFacet.interface.getFunction('redeem').selector,
                fundsFacet.interface.getFunction('totalAssets').selector,
                fundsFacet.interface.getFunction('managedDeposit').selector,
                fundsFacet.interface.getFunction('managedWithdraw').selector,
                fundsFacet.interface.getFunction('reallocate').selector,
                fundsFacet.interface.getFunction('strategyAssets').selector,
                fundsFacet.interface.getFunction('lastTotalAssets').selector,
                fundsFacet.interface.getFunction('underlyingBalance').selector,
                fundsFacet.interface.getFunction('underlyingAsset').selector,
                fundsFacet.interface.getFunction('yieldExtractor').selector,
                fundsFacet.interface.getFunction('accrueFee').selector,
                fundsFacet.interface.getFunction('strategyRewards').selector,
                fundsFacet.interface.getFunction('claimStrategyRewards').selector,
                fundsFacet.interface.getFunction('swapper').selector,
                fundsFacet.interface.getFunction('compound').selector,
                fundsFacet.interface.getFunction('migratePosition').selector,
            ],
        },
        {
            facet: await managementFacet.getAddress(),
            selectors: [
                managementFacet.interface.getFunction('addStrategy').selector,
                managementFacet.interface.getFunction('removeStrategy').selector,
                managementFacet.interface.getFunction('updateDepositQueue').selector,
                managementFacet.interface.getFunction('updateWithdrawQueue').selector,
                managementFacet.interface.getFunction('getDepositQueue').selector,
                managementFacet.interface.getFunction('getWithdrawQueue').selector,
                managementFacet.interface.getFunction('getStrategies').selector,
            ],
        },
        {
            facet: await accessFacet.getAddress(),
            selectors: [
                accessFacet.interface.getFunction('grantRole').selector,
                accessFacet.interface.getFunction('revokeRole').selector,
                accessFacet.interface.getFunction('checkRole').selector,
                accessFacet.interface.getFunction('getRoleMember').selector,
                accessFacet.interface.getFunction('getRoleMemberCount').selector,
                accessFacet.interface.getFunction('hasRole').selector,
            ],
        },
        {
            facet: await clientsFacet.getAddress(),
            selectors: [
                clientsFacet.interface.getFunction('createClient').selector,
                clientsFacet.interface.getFunction('transferClientOwnership').selector,
                clientsFacet.interface.getFunction('activateProject').selector,
                clientsFacet.interface.getFunction('setProjectInterceptor').selector,
                clientsFacet.interface.getFunction('setLockConfig').selector,
                clientsFacet.interface.getFunction('depositHook').selector,
                clientsFacet.interface.getFunction('redeemHook').selector,
                clientsFacet.interface.getFunction('lastProjectId').selector,
                clientsFacet.interface.getFunction('clientNameTaken').selector,
                clientsFacet.interface.getFunction('ownerToClientData').selector,
                clientsFacet.interface.getFunction('projectIdToClientName').selector,
                clientsFacet.interface.getFunction('projectIdActive').selector,
                clientsFacet.interface.getFunction('projectIdToProjectInterceptor').selector,
                clientsFacet.interface.getFunction('projectIdToLockConfig').selector,
                clientsFacet.interface.getFunction('userToProjectIdToUserLock').selector,
            ],
        },
    ]);
    await tx.wait(1);
};

export const initYelayLiteVault = async ({
    yelayLiteVault,
    yelayLiteVaultInit,
    swapper,
    underlyingAssetAddress,
    yieldExtractorAddress,
    uri,
}: {
    yelayLiteVault: IYelayLiteVault;
    yelayLiteVaultInit: YelayLiteVaultInit;
    swapper: Swapper;
    underlyingAssetAddress: string;
    yieldExtractorAddress: string;
    uri: string;
}) => {
    const tx = await yelayLiteVault.multicall([
        yelayLiteVault.interface.encodeFunctionData('setSelectorToFacets', [
            [
                {
                    facet: await yelayLiteVaultInit.getAddress(),
                    selectors: [yelayLiteVaultInit.interface.getFunction('init').selector],
                },
            ],
        ]),
        yelayLiteVaultInit.interface.encodeFunctionData('init', [
            await swapper.getAddress(),
            underlyingAssetAddress,
            yieldExtractorAddress,
            uri,
        ]),
        yelayLiteVault.interface.encodeFunctionData('setSelectorToFacets', [
            [
                {
                    facet: ethers.ZeroAddress,
                    selectors: [yelayLiteVaultInit.interface.getFunction('init').selector],
                },
            ],
        ]),
    ]);
    await tx.wait(1);
};

export const convertToAddresses = async (
    contracts: Record<string, BaseContract>,
): Promise<Record<string, string>> => {
    const contractAddresses: Record<string, string> = {};
    for (const [name, contract] of Object.entries(contracts)) {
        contractAddresses[name] = await contract.getAddress();
    }
    return contractAddresses;
};

export const impersonateSigner = async (address: string) => {
    const provider = new trueEthers.JsonRpcProvider(process.env.LOCAL_URL!);
    return new trueEthers.JsonRpcSigner(provider, address);
};
