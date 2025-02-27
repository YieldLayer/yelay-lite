import type { Signer } from 'ethers';
import fs from 'fs';
import { ethers, upgrades } from 'hardhat';
import {
    AccessFacet,
    ClientsFacet,
    FundsFacet,
    IYelayLiteVault,
    ManagementFacet,
} from '../typechain-types';
import { IMPLEMENTATION_STORAGE_SLOT } from './constants';

export const deployFacets = async (deployer: Signer, swapperAddress: string) => {
    const accessFacet = await ethers
        .getContractFactory('AccessFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
    const clientsFacet = await ethers
        .getContractFactory('ClientsFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
    const fundsFacet = await ethers
        .getContractFactory('FundsFacet', deployer)
        .then((f) => f.deploy(swapperAddress))
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
    const managementFacet = await ethers
        .getContractFactory('ManagementFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
    const ownerFacet = await ethers
        .getContractFactory('OwnerFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
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
    return yelayLiteVault.setSelectorToFacets.populateTransaction([
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
                fundsFacet.interface.getFunction('setYieldExtractor').selector,
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
    const swapper = await upgrades
        .deployProxy(swapperFactory, [ownerAddress], {
            kind: 'uups',
            unsafeAllow: ['state-variable-immutable'],
        })
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());

    const swapperImplementationAddress = await deployer
        .provider!.getStorage(swapper, IMPLEMENTATION_STORAGE_SLOT)
        .then((r) => ethers.dataSlice(r, 12));

    const vaultWrapperFactory = await ethers.getContractFactory('VaultWrapper', deployer);
    const vaultWrapper = await upgrades
        .deployProxy(vaultWrapperFactory, [ownerAddress], {
            kind: 'uups',
            constructorArgs: [wethAddress, swapper],
            unsafeAllow: ['state-variable-immutable'],
        })
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());

    const vaultWrapperImplementationAddress = await deployer
        .provider!.getStorage(vaultWrapper, IMPLEMENTATION_STORAGE_SLOT)
        .then((r) => ethers.dataSlice(r, 12));

    const { ownerFacet, fundsFacet, accessFacet, managementFacet, clientsFacet } =
        await deployFacets(deployer, swapper);

    fs.writeFileSync(
        deploymentPath,
        JSON.stringify(
            {
                swapper: {
                    proxy: swapper,
                    implementation: swapperImplementationAddress,
                },
                vaultWrapper: {
                    proxy: vaultWrapper,
                    implementation: vaultWrapperImplementationAddress,
                },
                ownerFacet,
                fundsFacet,
                accessFacet,
                managementFacet,
                clientsFacet,
                vaults: {},
                strategies: {},
            },
            null,
            4,
        ) + '\n',
    );
};

export const deployAaveV3Strategy = async (deployer: Signer, aaveV3Pool: string) => {
    return ethers
        .getContractFactory('AaveV3Strategy', deployer)
        .then((f) => f.deploy(aaveV3Pool))
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
};

export const deployMorphoBlueStrategy = async (deployer: Signer, morpho: string) => {
    return ethers
        .getContractFactory('MorphoBlueStrategy', deployer)
        .then((f) => f.deploy(morpho))
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
};

export const deployMorphoVaultStrategy = async (deployer: Signer, morphoVault: string) => {
    return ethers
        .getContractFactory('ERC4626Strategy', deployer)
        .then((f) => f.deploy(morphoVault))
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
};
