type Asset = 'usdc' | 'weth';

export type Contracts = {
    swapper: {
        proxy: string;
        implementation: string;
    };
    vaultWrapper: {
        proxy: string;
        implementation: string;
    };
    ownerFacet: string;
    fundsFacet: string;
    accessFacet: string;
    managementFacet: string;
    clientsFacet: string;
    vaults: { [K in Asset]: string | undefined };
    strategies: {};
};

const c = {} as Contracts;
c.vaults.usdc;
