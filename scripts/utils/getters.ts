import path from 'path';
import {
    IAccessFacet__factory,
    IClientsFacet__factory,
    IFundsFacet__factory,
    IManagementFacet__factory,
    IOwnerFacet__factory,
    IYelayLiteVault,
} from '../../typechain-types';

function getFunctionSelectors<
    T extends string,
    I extends { getFunction(name: T): { selector: string } },
>(i: I, functions: readonly T[]): Record<string, T> {
    return functions.reduce(
        (acc, f) => {
            acc[i.getFunction(f).selector] = f;
            return acc;
        },
        {} as Record<string, T>,
    );
}

export const getFundsFacetSelectors = () => {
    const i = IFundsFacet__factory.createInterface();
    const functions = [
        'totalSupply()',
        'totalSupply(uint256)',
        'lastTotalAssets',
        'lastTotalAssetsTimestamp',
        'lastTotalAssetsUpdateInterval',
        'setLastTotalAssetsUpdateInterval',
        'underlyingBalance',
        'underlyingAsset',
        'yieldExtractor',
        'swapper',
        'totalAssets',
        'strategyAssets',
        'strategyRewards',
        'deposit',
        'redeem',
        'migratePosition',
        'managedDeposit',
        'managedWithdraw',
        'reallocate',
        'swapRewards',
        'accrueFee',
        'claimStrategyRewards',
        'balanceOf',
        'uri',
        'setYieldExtractor',
    ] as const;
    return getFunctionSelectors(i, functions);
};

export const getManagementFacetSelectors = () => {
    const i = IManagementFacet__factory.createInterface();
    const functions = [
        'getStrategies',
        'getActiveStrategies',
        'getDepositQueue',
        'getWithdrawQueue',
        'updateDepositQueue',
        'updateWithdrawQueue',
        'addStrategy',
        'removeStrategy',
        'activateStrategy',
        'deactivateStrategy',
        'approveStrategy',
    ] as const;
    return getFunctionSelectors(i, functions);
};

export const getAccessFacetSelectors = () => {
    const i = IAccessFacet__factory.createInterface();
    const functions = [
        'checkRole',
        'setPaused',
        'selectorToPaused',
        'hasRole',
        'grantRole',
        'revokeRole',
        'renounceRole',
        'getRoleMember',
        'getRoleMemberCount',
    ] as const;
    return getFunctionSelectors(i, functions);
};

export const getClientFacetSelectors = () => {
    const i = IClientsFacet__factory.createInterface();
    const functions = [
        'createClient',
        'transferClientOwnership',
        'activateProject',
        'lastProjectId',
        'isClientNameTaken',
        'ownerToClientData',
        'projectIdToClientName',
        'projectIdActive',
    ] as const;
    return getFunctionSelectors(i, functions);
};

export const getOwnerFacetSelectors = () => {
    const i = IOwnerFacet__factory.createInterface();
    const functions = [
        'owner',
        'pendingOwner',
        'transferOwnership',
        'acceptOwnership',
        'setSelectorToFacets',
        'selectorToFacet',
    ] as const;
    return getFunctionSelectors(i, functions);
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

export const getContracts = async (chainId: number, testing = false) => {
    if (chainId !== 8453 && testing) {
        throw new Error('Testing is only on Base');
    }

    let fileName;
    if (chainId === 8453) {
        fileName = testing ? 'base-testing.json' : 'base-production.json';
    } else if (chainId === 1) {
        fileName = 'mainnet.json';
    } else if (chainId === 146) {
        fileName = 'sonic.json';
    } else {
        throw new Error(`No contracts for chainId ${chainId}`);
    }

    const contractsPath = path.resolve(process.cwd(), 'deployments', fileName);

    return import(contractsPath).then((f) => f.default);
};
