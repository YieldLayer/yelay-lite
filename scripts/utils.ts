import type { Signer } from 'ethers';
import fs from 'fs';
import { ethers, upgrades } from 'hardhat';
import {
    IAccessFacet__factory,
    IClientsFacet__factory,
    IFundsFacet__factory,
    IManagementFacet__factory,
    IOwnerFacet__factory,
    IYelayLiteVault,
    IYelayLiteVault__factory,
    Swapper__factory,
    VaultWrapper,
    VaultWrapper__factory,
} from '../typechain-types';
import { ADDRESSES, IMPLEMENTATION_STORAGE_SLOT, ROLES } from './constants';

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
    fundsFacet: string;
    managementFacet: string;
    accessFacet: string;
    clientsFacet: string;
}) => {
    return yelayLiteVault.setSelectorToFacets.populateTransaction([
        {
            facet: fundsFacet,
            selectors: getFundsFacetSelectors(),
        },
        {
            facet: managementFacet,
            selectors: getManagementFacetSelectors(),
        },
        {
            facet: accessFacet,
            selectors: getAccessFacetSelectors(),
        },
        {
            facet: clientsFacet,
            selectors: getClientFacetSelectors(),
        },
    ]);
};

export const getFundsFacetSelectors = () => {
    const i = IFundsFacet__factory.createInterface();
    return [
        i.getFunction('totalSupply()').selector,
        i.getFunction('totalSupply(uint256)').selector,
        i.getFunction('lastTotalAssets').selector,
        i.getFunction('lastTotalAssetsTimestamp').selector,
        i.getFunction('lastTotalAssetsUpdateInterval').selector,
        i.getFunction('setLastTotalAssetsUpdateInterval').selector,
        i.getFunction('underlyingBalance').selector,
        i.getFunction('underlyingAsset').selector,
        i.getFunction('yieldExtractor').selector,
        i.getFunction('swapper').selector,
        i.getFunction('totalAssets').selector,
        i.getFunction('strategyAssets').selector,
        i.getFunction('strategyRewards').selector,
        i.getFunction('deposit').selector,
        i.getFunction('redeem').selector,
        i.getFunction('migratePosition').selector,
        i.getFunction('managedDeposit').selector,
        i.getFunction('managedWithdraw').selector,
        i.getFunction('reallocate').selector,
        i.getFunction('swapRewards').selector,
        i.getFunction('accrueFee').selector,
        i.getFunction('claimStrategyRewards').selector,
        i.getFunction('balanceOf').selector,
        i.getFunction('uri').selector,
        i.getFunction('setYieldExtractor').selector,
    ];
};

export const getManagementFacetSelectors = () => {
    const i = IManagementFacet__factory.createInterface();
    return [
        i.getFunction('getStrategies').selector,
        i.getFunction('getActiveStrategies').selector,
        i.getFunction('getDepositQueue').selector,
        i.getFunction('getWithdrawQueue').selector,
        i.getFunction('updateDepositQueue').selector,
        i.getFunction('updateWithdrawQueue').selector,
        i.getFunction('addStrategy').selector,
        i.getFunction('removeStrategy').selector,
        i.getFunction('activateStrategy').selector,
        i.getFunction('deactivateStrategy').selector,
        i.getFunction('approveStrategy').selector,
    ];
};

export const getAccessFacetSelectors = () => {
    const i = IAccessFacet__factory.createInterface();
    return [
        i.getFunction('checkRole').selector,
        i.getFunction('setPaused').selector,
        i.getFunction('selectorToPaused').selector,
        i.getFunction('hasRole').selector,
        i.getFunction('grantRole').selector,
        i.getFunction('revokeRole').selector,
        i.getFunction('renounceRole').selector,
        i.getFunction('getRoleMember').selector,
        i.getFunction('getRoleMemberCount').selector,
    ];
};

export const getClientFacetSelectors = () => {
    const i = IClientsFacet__factory.createInterface();
    return [
        i.getFunction('createClient').selector,
        i.getFunction('transferClientOwnership').selector,
        i.getFunction('activateProject').selector,
        i.getFunction('lastProjectId').selector,
        i.getFunction('isClientNameTaken').selector,
        i.getFunction('ownerToClientData').selector,
        i.getFunction('projectIdToClientName').selector,
        i.getFunction('projectIdActive').selector,
    ];
};

export const getOwnerFacetSelectors = () => {
    const i = IOwnerFacet__factory.createInterface();
    return [
        i.getFunction('owner').selector,
        i.getFunction('pendingOwner').selector,
        i.getFunction('transferOwnership').selector,
        i.getFunction('acceptOwnership').selector,
        i.getFunction('setSelectorToFacets').selector,
        i.getFunction('selectorToFacet').selector,
    ];
};

export const checkFacets = async (
    yelayLiteVault: IYelayLiteVault,
    facet: string,
    selectors: string[],
) => {
    const facets: string[] = [];
    for (const s of selectors) {
        const f = await yelayLiteVault.selectorToFacet(s);
        facets.push(f);
    }
    facets.forEach((f, i) => {
        if (facet.toLowerCase() !== f.toLowerCase()) {
            console.error(`Selector ${selectors[i]} for ${facet} is not correctly set`);
        }
    });
};

export const getRoleMembers = async (yelayLiteVault: IYelayLiteVault, role: string) => {
    return yelayLiteVault
        .getRoleMemberCount(role)
        .then((r) =>
            Promise.all(
                new Array(Number(r)).fill(1).map((_, i) => yelayLiteVault.getRoleMember(role, i)),
            ),
        );
};

export const logRoleMembers = async (
    yelayLiteVault: IYelayLiteVault,
    roleName: keyof typeof ROLES,
) => {
    const r = await getRoleMembers(yelayLiteVault, ROLES[roleName]);
    console.log(`${roleName}: ${r.join(', ')}`);
};

export const checkImplementation = async (
    provider: typeof ethers.provider,
    proxy: string,
    implementation: string,
) => {
    const actualImplementation = await provider
        .getStorage(proxy, IMPLEMENTATION_STORAGE_SLOT)
        .then((r) => ethers.dataSlice(r, 12));
    if (implementation.toLowerCase() !== actualImplementation.toLowerCase()) {
        console.error(`Implementation doesn't match for: ${proxy} !`);
    }
};

export const checkSwapper = async (contract: IYelayLiteVault | VaultWrapper, swapper: string) => {
    const actualSwapper = await contract.swapper();
    if (actualSwapper.toLowerCase() !== swapper.toLowerCase()) {
        console.error(`Swapper doesn't match for ${await contract.getAddress()}`);
    }
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

export const checkSetup = async (contracts: any, provider: typeof ethers.provider) => {
    for (const asset of ['USDC', 'WETH'] as const) {
        console.log(`Working on ${asset} vault....`);
        console.log('');
        const yelayLiteVault = IYelayLiteVault__factory.connect(contracts.vaults[asset], provider);

        console.log('Checking selectors...');
        await checkFacets(yelayLiteVault, contracts.accessFacet, getAccessFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.ownerFacet, getOwnerFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.fundsFacet, getFundsFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.managementFacet, getManagementFacetSelectors());
        await checkFacets(yelayLiteVault, contracts.clientsFacet, getClientFacetSelectors());

        console.log('');

        console.log(`Getting addresses...`);
        await yelayLiteVault.owner().then((r) => console.log(`Vault owner: ${r}`));
        await yelayLiteVault.yieldExtractor().then((r) => console.log(`YieldExtractor: ${r}`));
        await yelayLiteVault.underlyingAsset().then((r) => console.log(`Underlying asset: ${r}`));

        console.log('');
        console.log('Logging role members....');
        console.log('');

        await logRoleMembers(yelayLiteVault, 'STRATEGY_AUTHORITY');
        console.log('');
        await logRoleMembers(yelayLiteVault, 'QUEUES_OPERATOR');
        console.log('');
        await logRoleMembers(yelayLiteVault, 'FUNDS_OPERATOR');
        console.log('');
        await logRoleMembers(yelayLiteVault, 'SWAP_REWARDS_OPERATOR');
        console.log('');
        await logRoleMembers(yelayLiteVault, 'PAUSER');
        console.log('');
        await logRoleMembers(yelayLiteVault, 'UNPAUSER');

        console.log('');
        console.log('Checking swapper on vault....');
        console.log('');

        await checkSwapper(yelayLiteVault, contracts.swapper.proxy);
        console.log('');
    }

    console.log(`Working on swapper and vaultWrapper...`);
    console.log('');

    await Swapper__factory.connect(contracts.swapper.proxy, provider)
        .owner()
        .then((r) => console.log(`Swapper owner: ${r}`));
    await VaultWrapper__factory.connect(contracts.vaultWrapper.proxy, provider)
        .owner()
        .then((r) => console.log(`VaultWrapper owner: ${r}`));

    console.log('');
    console.log('Checking swapper implementation....');
    console.log('');

    await checkImplementation(provider, contracts.swapper.proxy, contracts.swapper.implementation);

    console.log('');
    console.log('Checking vaultWrapper implementation....');
    console.log('');

    await checkImplementation(
        provider,
        contracts.vaultWrapper.proxy,
        contracts.vaultWrapper.implementation,
    );

    console.log('');
    console.log('Checking swapper on vaultWrapper....');
    console.log('');

    await checkSwapper(
        VaultWrapper__factory.connect(contracts.vaultWrapper.proxy, provider),
        contracts.swapper.proxy,
    );

    console.log('');
    console.log('Checking one inch whitelisting on swapper...');
    console.log('');
    await Swapper__factory.connect(contracts.swapper.proxy, provider)
        .exchangeAllowlist(ADDRESSES.BASE.ONE_INCH_ROUTER_V6)
        .then((r) => {
            if (!r) {
                console.error(`one inch doesn't allowed`);
            }
        });
};

export const deployVault = async (
    deployer: Signer,
    contracts: any,
    deployArgs: { underlyingAsset: string; yieldExtractor: string; uri: string },
    assetSymbol: string,
    deploymentPath: string,
) => {
    const deployerAddress = await deployer.getAddress();
    const yelayLiteVault = await ethers
        .getContractFactory('YelayLiteVault', deployer)
        .then((f) =>
            f.deploy(
                deployerAddress,
                contracts.ownerFacet,
                deployArgs.underlyingAsset,
                deployArgs.yieldExtractor,
                deployArgs.uri,
            ),
        )
        .then(async (c) => {
            const d = await c.waitForDeployment();
            const tx = await ethers.provider.getTransaction(d.deploymentTransaction()!.hash);
            console.log(`Vault: ${await c.getAddress()}`);
            console.log(`Vault creation blocknumber: ${tx?.blockNumber}`);
            const block = await ethers.provider.getBlock(tx!.blockNumber!);
            console.log(`Timestamp: ${block?.timestamp}`);
            return d.getAddress();
        })
        .then((a) => IYelayLiteVault__factory.connect(a, deployer));

    contracts.vaults[assetSymbol] = await yelayLiteVault.getAddress();
    fs.writeFileSync(deploymentPath, JSON.stringify(contracts, null, 4) + '\n');
};
