import {
    AccessFacet,
    ClientsFacet,
    FundsFacet,
    ManagementFacet,
    Swapper,
    TokenFacet,
    YelayLiteVault,
    YelayLiteVaultInit,
} from '../typechain-types';

export type Contracts = {
    yelayLiteVault: YelayLiteVault;
    tokenFacet: TokenFacet;
    fundsFacet: FundsFacet;
    accessFacet: AccessFacet;
    managementFacet: ManagementFacet;
    clientsFacet: ClientsFacet;
    yelayLiteVaultInit: YelayLiteVaultInit;
    swapper: Swapper;
};
