# Initial setup

- `forge soldeer install`
- `npm i`

# Test

- create .env file and specify `MAINNET_URL`
- `forge test`

# Protocol Overview

The YelayLiteVault is an ERC1155-based vault designed to hold a single underlying ERC20 token. It is implemented as a proxy contract, supporting multiple implementations (facets) in a manner similar to the EIP-2535 Diamond Standard, but as a simplified version. The owner of the vault can manage facets and their associated methods, making the vault upgradeable.

The YelayLiteVault is designed for use by multiple clients. For each client, the owner of the vault can allocate a range of IDs, which can represent distinct projects associated with that client.

All yield earned by the vault will be extracted to a designated smart contract (currently out of scope). This contract will handle further distribution according to the client’s specific requirements, such as airdrops, points, or other tokens. The contributions to the yield or APY of the vault for each client, project, or user will be calculated off-chain.

The YelayLiteVault is a managed vault where specific roles govern its operation:

- STRATEGY_AUTHORITY: Responsible for adding and removing strategies within the vault.
- QUEUES_OPERATOR: Configures the deposit and withdrawal queues based on the existing strategies. These queues define the ordered list of strategies with which users will interact first.
- FUNDS_OPERATOR: Handles reallocations, reward claims to optimize fund management.
- SWAP_REWARDS_OPERATOR: Responsible for handling swapRewards only (compounding).
- PAUSER/UNPAUSER: Selective pausing/unpausing of specific functions.

It is assumed that the vault operator acts in good faith, striving to achieve the highest possible yield while carefully considering the risks associated with each strategy.

Deposits and withdrawals are immediate. For deposits, if the deposit queue is empty or if all deposit attempts into the strategies in the queue fail, the operation is still considered successful. In such cases, the funds will simply be held in the vault. Upon depositing, users receive ERC1155 tokens representing their position in a specific project (e.g., IDs 1, 45, etc.). These tokens are non-transferable; however, users can transfer their position between projects within the same client’s allocated ID range. For example, if a client’s range is 2000–2999 and a user previously deposited into 2001, they can migrate their position to 2010 within that range.

# Future Features

- **Deposit Locks**: In the future, we plan to introduce deposit locks. Clients with specific ID ranges will be restricted to creating projects where user deposits must remain in the vault for a predefined period. Only after this period has elapsed can the position be redeemed or migrated.

- **Cross-Chain Support**: cross-chain support will be implemented using CCIP (Chainlink Cross-Chain Interoperability Protocol). This will enable users from other chains to deposit on L2, while actual yield generation occurs on Mainnet. Withdrawals will follow a similar process: users will make a request on L2 and receive their funds from Mainnet.
