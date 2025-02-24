import type { Signer } from 'ethers';
import fs from 'fs';
import { ethers, upgrades } from 'hardhat';
import {
    AccessFacet,
    ClientsFacet,
    FundsFacet,
    IYelayLiteVault,
    ManagementFacet,
    Swapper,
    VaultWrapper,
} from '../typechain-types';
import { IMPLEMENTATION_STORAGE_SLOT } from './constants';

export const deployFacets = async (deployer: Signer, swapperAddress: string) => {
    const accessFacet = await ethers
        .getContractFactory('AccessFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment());
    const clientsFacet = await ethers
        .getContractFactory('ClientsFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment());
    const fundsFacet = await ethers
        .getContractFactory('FundsFacet', deployer)
        .then((f) => f.deploy(swapperAddress))
        .then((r) => r.waitForDeployment());
    const managementFacet = await ethers
        .getContractFactory('ManagementFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment());
    const ownerFacet = await ethers
        .getContractFactory('OwnerFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment());
    return { ownerFacet, fundsFacet, managementFacet, accessFacet, clientsFacet };
};

export const prepareSetSelectorFacets = async ({
    yelayLiteVault,
    fundsFacet,
    managementFacet,
    accessFacet,
    clientsFacet,
}: {
    yelayLiteVault: IYelayLiteVault;
    fundsFacet: FundsFacet;
    managementFacet: ManagementFacet;
    accessFacet: AccessFacet;
    clientsFacet: ClientsFacet;
}) => {
    return await yelayLiteVault.setSelectorToFacets.populateTransaction([
        {
            facet: await fundsFacet.getAddress(),
            selectors: [
                fundsFacet.interface.getFunction('totalSupply()').selector,
                fundsFacet.interface.getFunction('totalSupply(uint256)').selector,
                fundsFacet.interface.getFunction('lastTotalAssets').selector,
                fundsFacet.interface.getFunction('lastTotalAssetsTimestamp').selector,
                fundsFacet.interface.getFunction('lastTotalAssetsUpdateInterval').selector,
                fundsFacet.interface.getFunction('setLastTotalAssetsUpdateInterval').selector,
                fundsFacet.interface.getFunction('underlyingBalance').selector,
                fundsFacet.interface.getFunction('underlyingAsset').selector,
                fundsFacet.interface.getFunction('yieldExtractor').selector,
                fundsFacet.interface.getFunction('swapper').selector,
                fundsFacet.interface.getFunction('totalAssets').selector,
                fundsFacet.interface.getFunction('strategyAssets').selector,
                fundsFacet.interface.getFunction('strategyRewards').selector,
                fundsFacet.interface.getFunction('deposit').selector,
                fundsFacet.interface.getFunction('redeem').selector,
                fundsFacet.interface.getFunction('migratePosition').selector,
                fundsFacet.interface.getFunction('managedDeposit').selector,
                fundsFacet.interface.getFunction('managedWithdraw').selector,
                fundsFacet.interface.getFunction('reallocate').selector,
                fundsFacet.interface.getFunction('swapRewards').selector,
                fundsFacet.interface.getFunction('accrueFee').selector,
                fundsFacet.interface.getFunction('claimStrategyRewards').selector,
                fundsFacet.interface.getFunction('balanceOf').selector,
                fundsFacet.interface.getFunction('uri').selector,
            ],
        },
        {
            facet: await managementFacet.getAddress(),
            selectors: [
                managementFacet.interface.getFunction('getStrategies').selector,
                managementFacet.interface.getFunction('getActiveStrategies').selector,
                managementFacet.interface.getFunction('getDepositQueue').selector,
                managementFacet.interface.getFunction('getWithdrawQueue').selector,
                managementFacet.interface.getFunction('updateDepositQueue').selector,
                managementFacet.interface.getFunction('updateWithdrawQueue').selector,
                managementFacet.interface.getFunction('addStrategy').selector,
                managementFacet.interface.getFunction('removeStrategy').selector,
                managementFacet.interface.getFunction('activateStrategy').selector,
                managementFacet.interface.getFunction('deactivateStrategy').selector,
                managementFacet.interface.getFunction('approveStrategy').selector,
            ],
        },
        {
            facet: await accessFacet.getAddress(),
            selectors: [
                accessFacet.interface.getFunction('checkRole').selector,
                accessFacet.interface.getFunction('setPaused').selector,
                accessFacet.interface.getFunction('selectorToPaused').selector,
                accessFacet.interface.getFunction('hasRole').selector,
                accessFacet.interface.getFunction('grantRole').selector,
                accessFacet.interface.getFunction('revokeRole').selector,
                accessFacet.interface.getFunction('renounceRole').selector,
                accessFacet.interface.getFunction('getRoleMember').selector,
                accessFacet.interface.getFunction('getRoleMemberCount').selector,
            ],
        },
        {
            facet: await clientsFacet.getAddress(),
            selectors: [
                clientsFacet.interface.getFunction('createClient').selector,
                clientsFacet.interface.getFunction('transferClientOwnership').selector,
                clientsFacet.interface.getFunction('activateProject').selector,
                clientsFacet.interface.getFunction('lastProjectId').selector,
                clientsFacet.interface.getFunction('isClientNameTaken').selector,
                clientsFacet.interface.getFunction('ownerToClientData').selector,
                clientsFacet.interface.getFunction('projectIdToClientName').selector,
                clientsFacet.interface.getFunction('projectIdActive').selector,
            ],
        },
    ]);
};

export const deployInfra = async (
    deployer: Signer,
    ownerAddress: string,
    wethAddress: string,
    deploymentPath: string,
) => {
    const swapperFactory = await ethers.getContractFactory('Swapper', deployer);
    const swapper = (await upgrades
        .deployProxy(swapperFactory, [ownerAddress], {
            kind: 'uups',
        })
        .then((r) => r.deploymentTransaction())) as Swapper;

    const swapperAddress = await swapper.getAddress();
    const swapperImplementationAddress = await deployer.provider!.getStorage(
        swapperAddress,
        IMPLEMENTATION_STORAGE_SLOT,
    );

    const vaultWrapperFactory = await ethers.getContractFactory('VaultWrapper', deployer);
    const vaultWrapper = (await upgrades.deployProxy(vaultWrapperFactory, [ownerAddress], {
        kind: 'uups',
        constructorArgs: [wethAddress, swapperAddress],
    })) as unknown as VaultWrapper;

    const vaultWrapperAddress = await vaultWrapper.getAddress();
    const vaultWrapperImplementationAddress = await deployer.provider!.getStorage(
        vaultWrapperAddress,
        IMPLEMENTATION_STORAGE_SLOT,
    );

    const { ownerFacet, fundsFacet, accessFacet, managementFacet, clientsFacet } =
        await deployFacets(deployer, swapperAddress);

    const ownerFacetAddress = await ownerFacet.getAddress();
    const fundsFacetAddress = await fundsFacet.getAddress();
    const accessFacetAddress = await accessFacet.getAddress();
    const managementFacetAddress = await managementFacet.getAddress();
    const clientsFacetAddress = await clientsFacet.getAddress();

    fs.writeFileSync(
        deploymentPath,
        JSON.stringify(
            {
                swapper: {
                    proxy: swapperAddress,
                    implementation: swapperImplementationAddress,
                },
                vaultWrapper: {
                    proxy: vaultWrapperAddress,
                    implementation: vaultWrapperImplementationAddress,
                },
                ownerFacet: ownerFacetAddress,
                fundsFacet: fundsFacetAddress,
                accessFacet: accessFacetAddress,
                managementFacet: managementFacetAddress,
                clientsFacet: clientsFacetAddress,
                vaults: {},
                strategies: {},
            },
            null,
            4,
        ) + '\n',
    );
};
