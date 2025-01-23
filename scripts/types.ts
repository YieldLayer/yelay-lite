import {
    AccessFacet,
    ClientsFacet,
    FundsFacet,
    ManagementFacet,
    OwnerFacet,
    Swapper,
    YelayLiteVault,
} from '../typechain-types';

export type Contracts = {
    yelayLiteVault: YelayLiteVault;
    fundsFacet: FundsFacet;
    accessFacet: AccessFacet;
    managementFacet: ManagementFacet;
    clientsFacet: ClientsFacet;
    swapper: Swapper;
    ownerFacet: OwnerFacet;
};
