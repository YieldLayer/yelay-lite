# Initial setup

- forge soldeer install
- npm i

# Test

- create .env file and specify MAINNET_URL
- forge test

# Architecture

YelayLiteVault is an ERC1155 vault which has one underlying ERC20 token.
It is a Proxy which has various facets (implementations) (aka EIP-2535 standard).
Owner of the vault can manage facets and methods on them. Moreover, owner can allow clients to create their own "pools" which correspond to certain "id" (see ClientsFacet). 

The vault is managed, strategies can be added and removed by STRATEGY_AUTHORITY role (see ManagementFacet).
QUEUES_OPERATOR role defines based on existing strategies the deposit and withdraw queues (ordered list of strategies with which user would interact first).
FUNDS_OPERATOR role can do reallocations, rewards claiming and compounding.

Once project id is activated by client - users are able to deposit assets into vault. 
Deposits are immediate, even if deposit queue is empty or deposit into all strategies from deposit queue has failed - it will be successful. User receives ERC1155 with particular project id (e.g. 1, 45 etc).
This nfts are not transferrable, although it is possible for users to transfer their position between projects of the same client (e.g. Client has a range of 2000 - 2999, user has previously deposited into 2001, thus she can migrate position to 2010).



