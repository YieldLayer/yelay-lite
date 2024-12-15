import fs from 'fs';
import { ethers, upgrades } from 'hardhat';

import {
    ERC20__factory,
    IPool__factory,
    IYelayLiteVault__factory,
    Swapper,
} from '../../typechain-types';
import { AAVE_V3_POOL, USDC_ADDRESS, USDC_WHALE } from '../constants';
import { Contracts } from '../types';
import {
    convertToAddresses,
    deployFacets,
    impersonateSigner,
    initYelayLiteVault,
    setSelectorFacets,
} from '../utils';

// launch local fork first
// source .env && anvil --fork-url ${MAINNET_URL} --auto-impersonate --block-base-fee-per-gas 1 --block-time 1

async function main() {
    const [deployer, yieldExtractor, user1, user2, user3] = await ethers.getSigners();

    const swapperFactory = await ethers.getContractFactory('Swapper', deployer);
    const swapper = (await upgrades.deployProxy(swapperFactory, [deployer.address], {
        kind: 'transparent',
    })) as unknown as Swapper;

    const { ownerFacet, tokenFacet, fundsFacet, accessFacet, managementFacet, clientsFacet } =
        await deployFacets(deployer);

    const yelayLiteVaultInit = await ethers
        .getContractFactory('YelayLiteVaultInit', deployer)
        .then((f) => f.deploy());

    const yelayLiteVault = await ethers
        .getContractFactory('YelayLiteVault', deployer)
        .then((f) => f.deploy(deployer.address, ownerFacet.getAddress()))
        .then(async (c) => {
            const d = await c.waitForDeployment();
            const block = await ethers.provider.getTransaction(d.deploymentTransaction()!.hash);
            console.log(`Vault creation blocknumber: ${block?.blockNumber}`);
            return d.getAddress();
        })
        .then((a) => IYelayLiteVault__factory.connect(a, deployer));

    await setSelectorFacets({
        yelayLiteVault,
        fundsFacet,
        tokenFacet,
        managementFacet,
        accessFacet,
        clientsFacet,
    });

    await initYelayLiteVault({
        yelayLiteVault,
        yelayLiteVaultInit,
        swapper,
        yieldExtractorAddress: yieldExtractor.address,
        underlyingAssetAddress: USDC_ADDRESS,
        uri: 'test',
    });

    await yelayLiteVault.createClient(deployer.address, 1, 100, ethers.encodeBytes32String('test'));
    await yelayLiteVault.activateProject(1);

    console.log('Adding strategy to vault');
    await yelayLiteVault.grantRole(
        '0xbf935b513649871c60054e0279e4e5798d3dfd05785c3c3c5b311fb39ec270fe',
        deployer.address,
    );
    await yelayLiteVault.grantRole(
        '0xb95e9900cc6e2c54ae5b00d8f86008697b24bf67652a40653ea0c09c6fc4a856',
        deployer.address,
    );
    const aaveStrategyFactory = await ethers.getContractFactory('AaveV3Strategy', deployer);
    const aaveStrategy = await aaveStrategyFactory.deploy(AAVE_V3_POOL);
    await yelayLiteVault.addStrategy({
        adapter: await aaveStrategy.getAddress(),
        supplement: new ethers.AbiCoder().encode(
            ['address', 'address'],
            [
                USDC_ADDRESS,
                await IPool__factory.connect(AAVE_V3_POOL, deployer)
                    .getReserveData(USDC_ADDRESS)
                    .then((r) => r.aTokenAddress),
            ],
        ),
    });
    await yelayLiteVault.updateDepositQueue([0]);
    await yelayLiteVault.updateWithdrawQueue([0]);

    const contracts: Contracts = {
        yelayLiteVault,
        tokenFacet,
        fundsFacet,
        accessFacet,
        managementFacet,
        clientsFacet,
        yelayLiteVaultInit,
        swapper,
    };

    fs.writeFileSync(
        './deployments/local.json',
        JSON.stringify(await convertToAddresses(contracts), null, 4) + '\n',
    );

    console.log('Successful local deployment');

    const usdcWhale = await impersonateSigner(USDC_WHALE);
    const usdc = ERC20__factory.connect(USDC_ADDRESS, usdcWhale);
    await usdc.transfer(user1.address, ethers.parseUnits('10000', 6));
    await usdc.transfer(user2.address, ethers.parseUnits('10000', 6));
    await usdc.transfer(user3.address, ethers.parseUnits('10000', 6));

    await usdc.connect(user1).approve(await yelayLiteVault.getAddress(), ethers.MaxUint256);
    await usdc.connect(user2).approve(await yelayLiteVault.getAddress(), ethers.MaxUint256);
    await usdc.connect(user3).approve(await yelayLiteVault.getAddress(), ethers.MaxUint256);

    console.log('Provided USDC to test users');
}

main();
