import type { Signer } from 'ethers';
import fs from 'fs';
import { ethers, upgrades } from 'hardhat';
import { IYelayLiteVault, IYelayLiteVault__factory } from '../../typechain-types';
import { getExpectedAddresses, IMPLEMENTATION_STORAGE_SLOT } from '../constants';
import { isTesting } from './common';
import {
    getAccessFacetSelectors,
    getClientFacetSelectors,
    getContracts,
    getContractsPath,
    getFundsFacetSelectors,
    getManagementFacetSelectors,
} from './getters';

export const deployAccessFacet = async (deployer: Signer) => {
    return ethers
        .getContractFactory('AccessFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
};

export const deployClientsFacet = async (deployer: Signer) => {
    return ethers
        .getContractFactory('ClientsFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
};

export const deployFundsFacet = async (
    deployer: Signer,
    swapperAddress: string,
    merklDistributor = ethers.ZeroAddress,
) => {
    return ethers
        .getContractFactory('FundsFacet', deployer)
        .then((f) => f.deploy(swapperAddress, merklDistributor))
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
};

export const deployManagementFacet = async (deployer: Signer) => {
    return ethers
        .getContractFactory('ManagementFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
};

export const deployOwnerFacet = async (deployer: Signer) => {
    return ethers
        .getContractFactory('OwnerFacet', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
};

export const deployFacets = async (
    deployer: Signer,
    swapperAddress: string,
    merklAddress = ethers.ZeroAddress,
) => {
    const accessFacet = await deployAccessFacet(deployer);
    const clientsFacet = await deployClientsFacet(deployer);
    const fundsFacet = await deployFundsFacet(deployer, swapperAddress, merklAddress);
    const managementFacet = await deployManagementFacet(deployer);
    const ownerFacet = await deployOwnerFacet(deployer);
    return { ownerFacet, fundsFacet, managementFacet, accessFacet, clientsFacet };
};

// export const prepareSetSelectorFacets = async ({
//     yelayLiteVault,
//     fundsFacet,
//     managementFacet,
//     accessFacet,
//     clientsFacet,
// }: {
//     yelayLiteVault: IYelayLiteVault;
//     fundsFacet: string;
//     managementFacet: string;
//     accessFacet: string;
//     clientsFacet: string;
// }) => {
//     return yelayLiteVault.setSelectorToFacets.populateTransaction([
//         {
//             facet: fundsFacet,
//             selectors: Object.keys(getFundsFacetSelectors()),
//         },
//         {
//             facet: managementFacet,
//             selectors: Object.keys(getManagementFacetSelectors()),
//         },
//         {
//             facet: accessFacet,
//             selectors: Object.keys(getAccessFacetSelectors()),
//         },
//         {
//             facet: clientsFacet,
//             selectors: Object.keys(getClientFacetSelectors()),
//         },
//     ]);
// };

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

export const deployInfraV2 = async (
    deployer: Signer,
    ownerAddress: string,
    wethAddress: string,
    merklAddress: string,
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
        await deployFacets(deployer, swapper, merklAddress);

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

export const deployERC4626Strategy = async (deployer: Signer) => {
    return ethers
        .getContractFactory('ERC4626Strategy', deployer)
        .then((f) => f.deploy())
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
};

export const deployGearboxV3Strategy = async (deployer: Signer, gearToken: string) => {
    return ethers
        .getContractFactory('GearboxV3Strategy', deployer)
        .then((f) => f.deploy(gearToken))
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());
};

// export const deployVault = async (
//     deployer: Signer,
//     contracts: any,
//     deployArgs: { underlyingAsset: string; yieldExtractor: string; uri: string },
//     assetSymbol: string,
//     deploymentPath: string,
// ) => {
//     const deployerAddress = await deployer.getAddress();
//     const yelayLiteVault = await ethers
//         .getContractFactory('YelayLiteVault', deployer)
//         .then((f) =>
//             f.deploy(
//                 deployerAddress,
//                 contracts.ownerFacet,
//                 deployArgs.underlyingAsset,
//                 deployArgs.yieldExtractor,
//                 deployArgs.uri,
//             ),
//         )
//         .then(async (c) => {
//             const d = await c.waitForDeployment();
//             const tx = await ethers.provider.getTransaction(d.deploymentTransaction()!.hash);
//             console.log(`Vault: ${await c.getAddress()}`);
//             console.log(`Vault creation blocknumber: ${tx?.blockNumber}`);
//             const block = await ethers.provider.getBlock(tx!.blockNumber!);
//             console.log(`Timestamp: ${block?.timestamp}`);
//             return d.getAddress();
//         })
//         .then((a) => IYelayLiteVault__factory.connect(a, deployer));

//     contracts.vaults[assetSymbol] = await yelayLiteVault.getAddress();
//     fs.writeFileSync(deploymentPath, JSON.stringify(contracts, null, 4) + '\n');
// };

export const deployDepositLockPlugin = async (deployer: Signer) => {
    const chainId = Number((await deployer.provider!.getNetwork()).chainId);
    const testing = isTesting();
    const contractsPath = getContractsPath(chainId, testing);
    const contracts = await getContracts(contractsPath);
    const owner = getExpectedAddresses(chainId, testing).owner;

    if (contracts.depositLockPlugin) {
        throw new Error(`DepositLockPlugin already deployed for ${chainId}`);
    }

    const depositLockPluginFactory = await ethers.getContractFactory('DepositLockPlugin', deployer);
    const depositLockPlugin = await upgrades
        .deployProxy(depositLockPluginFactory, [owner], {
            kind: 'uups',
        })
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());

    const depositLockPluginImplementation = await deployer
        .provider!.getStorage(depositLockPlugin, IMPLEMENTATION_STORAGE_SLOT)
        .then((r) => ethers.dataSlice(r, 12));

    contracts.depositLockPlugin = {
        proxy: depositLockPlugin,
        implementation: depositLockPluginImplementation,
    };

    fs.writeFileSync(contractsPath, JSON.stringify(contracts, null, 4) + '\n');
};

export const deployYieldExtractor = async (deployer: Signer) => {
    const chainId = Number((await deployer.provider!.getNetwork()).chainId);
    const testing = isTesting();
    const contractsPath = getContractsPath(chainId, testing);
    const contracts = await getContracts(contractsPath);
    const owner = getExpectedAddresses(chainId, testing).owner;
    const yieldPublisher = getExpectedAddresses(chainId, testing).yieldPublisher;

    if (contracts.yieldExtractor) {
        throw new Error(`YieldExtractor already deployed for ${chainId}`);
    }

    const yieldExtractorFactory = await ethers.getContractFactory('YieldExtractor', deployer);
    const yieldExtractor = await upgrades
        .deployProxy(yieldExtractorFactory, [owner, yieldPublisher], {
            kind: 'uups',
        })
        .then((r) => r.waitForDeployment())
        .then((r) => r.getAddress());

    const yieldExtractorImplementation = await deployer
        .provider!.getStorage(yieldExtractor, IMPLEMENTATION_STORAGE_SLOT)
        .then((r) => ethers.dataSlice(r, 12));

    contracts.yieldExtractor = {
        proxy: yieldExtractor,
        implementation: yieldExtractorImplementation,
    };

    fs.writeFileSync(contractsPath, JSON.stringify(contracts, null, 4) + '\n');
};

export const deployDeterministic = async (
    deployer: Signer,
    deploymentProxy: string,
    salt: string,
    initCode: string,
): Promise<string> => {
    const data = ethers.concat([salt, initCode]);
    const tx = await deployer.sendTransaction({
        to: deploymentProxy,
        data: data,
    });
    const receipt = await tx.wait();
    if (!receipt) {
        throw new Error('Transaction failed');
    }

    return receipt.contractAddress!;
};

export const deployERC4626PluginFactory = async (
    deployer: Signer,
    yieldExtractor: string,
    factorySalt: string,
    chainId: number,
    testing: boolean,
): Promise<{ factory: string; implementation: string }> => {
    const DEPLOYMENT_PROXY = '0x4e59b44847b379578588920ca78fbf26c0b4956c';
    const owner = getExpectedAddresses(chainId, testing).owner;

    // Deploy ERC4626Plugin implementation deterministically
    console.log('Deploying ERC4626Plugin implementation...');
    const ERC4626Plugin = await ethers.getContractFactory('ERC4626Plugin', deployer);
    const pluginImplementation = await ERC4626Plugin.deploy(yieldExtractor);
    await pluginImplementation.waitForDeployment();
    const implementationAddress = await pluginImplementation.getAddress();
    console.log('ERC4626Plugin implementation deployed at:', implementationAddress);

    // Deploy ERC4626PluginFactory deterministically
    console.log('Deploying ERC4626PluginFactory...');
    const FactoryFactory = await ethers.getContractFactory('ERC4626PluginFactory', deployer);
    const factoryInitCode = ethers.concat([
        FactoryFactory.bytecode,
        ethers.AbiCoder.defaultAbiCoder().encode(
            ['address', 'address'],
            [owner, implementationAddress],
        ),
    ]);

    const factoryAddress = await deployDeterministic(
        deployer,
        DEPLOYMENT_PROXY,
        factorySalt,
        factoryInitCode,
    );
    console.log('ERC4626PluginFactory deployed at:', factoryAddress);
    return { factory: factoryAddress, implementation: implementationAddress };
};
