// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {Utils} from "../Utils.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {OWNER, USDCe} from "../Constants.sol";
import {IFundsFacet} from "src/interfaces/IFundsFacet.sol";
import {SelectorsToFacet} from "src/interfaces/IOwnerFacet.sol";
import {IMerklDistributor} from "src/interfaces/external/merkl/IMerklDistributor.sol";
import {FundsFacet} from "src/facets/FundsFacet.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

contract CompoundTest is Test {
    using Utils for address;

    address constant owner = OWNER;
    address constant user = address(0x01);
    IYelayLiteVault yelayLiteVault = IYelayLiteVault(0x56b0c5C989C65e712463278976ED26D6e07592ab);
    IMerklDistributor merklDistributor = IMerklDistributor(0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae);
    IERC20 ws = IERC20(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    IERC20 underlyingAsset = IERC20(USDCe);

    function _getFundsFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IFundsFacet.claimMerklRewards.selector;
        return selectors;
    }

    function setUp() external {
        vm.createSelectFork(vm.envString("SONIC_URL"), 33198510);

        vm.startPrank(owner);
        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);

        selectorsToFacets[0] = SelectorsToFacet({
            facet: address(new FundsFacet(ISwapper(address(0)), IMerklDistributor(merklDistributor))),
            selectors: _getFundsFacetSelectors()
        });
        yelayLiteVault.setSelectorToFacets(selectorsToFacets);
        vm.stopPrank();
    }

    function _getTokens() internal pure returns (address[] memory) {
        address[] memory tokens = new address[](2);
        tokens[0] = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        tokens[1] = 0x6C5E14A212c1C3e4Baf6f871ac9B1a969918c131;
        return tokens;
    }

    function _getAmounts() internal pure returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2066015760186535436007;
        amounts[1] = 105448322415833208;
        return amounts;
    }

    function _getProofs() internal pure returns (bytes32[][] memory) {
        bytes32[][] memory proofs = new bytes32[][](2);

        proofs[0] = new bytes32[](16);
        proofs[0][0] = 0x1cbe08f63230ddb1f7b0810a0f3fd71226bea79377bf7ab0f8a5ea72fd67db1a;
        proofs[0][1] = 0xb982f7019a206eff1cdd5298a1ea904a9e934dcc808819a72b14fcbfa8ef5b34;
        proofs[0][2] = 0x91e9e7553bba00ebe29537060f80c11bef07942832e7a539a300d1d5bbddf921;
        proofs[0][3] = 0xd12c70a864130c780f800ea66358b8ce6469c9f563c194d132a62b20a0c8a3ae;
        proofs[0][4] = 0x04f0fea74b46db5ae8eddfa71627dafa487a19d170386315c8da8c40e2807022;
        proofs[0][5] = 0x3692f182dff72784b0d7b4c479adc7cb351616970e00b6ea7e5083dda317bad9;
        proofs[0][6] = 0xa7f5eff1953a564fd4b48af887cfe7704dbb366f681904ff6d112cd1ebe30b8c;
        proofs[0][7] = 0x0d611213b5590f8a8eaf7a6704e2536d5fe8e7bb4eeb84f38d55e133d8696a6b;
        proofs[0][8] = 0x98c9dd08d72741551bd6f7e6848bacda27ead3775a13497dfc6729a01e3f4c19;
        proofs[0][9] = 0xfa4e09f56aae852413a5abd890961c8f197c0b338e2d4568eb2e6867340ffc5f;
        proofs[0][10] = 0x968177c88e3600e8b114024ab1f5bf30dc2509a01c3708ed8dfb254ebdba18d4;
        proofs[0][11] = 0x47f9d16811f900b6a05f7376845bcca52575a4406471699681d881897fbe715d;
        proofs[0][12] = 0x3ca1c01a34656e856f2aba3e7ce99971b12b380222de0dcb736c9c9ac29c8426;
        proofs[0][13] = 0x7b8629f536ac547f921a4c9315a9b05fd8cf973f2565a92a498c479893fdbb6a;
        proofs[0][14] = 0xacc2a0302f552bb48e179874d13d4dab28277193cfb494128ec59fdae42447ce;
        proofs[0][15] = 0x062adfd1058164fecf1c51f6dcb1e3d0f76aab49889aadb1a74f7eb7fcbb402f;

        proofs[1] = new bytes32[](16);
        proofs[1][0] = 0x90aca9c93edd2d02776e601441052d83b400d123c0eb81af22b90d96d14a3c82;
        proofs[1][1] = 0x370e6ab22204fd4b7d1260cc02e8b59124560a69ccf694e42fde47d8d1abcc95;
        proofs[1][2] = 0x39098dc5b838da2ebd78426233bdbb081a736167dafe4d11368f4e5eb6350cde;
        proofs[1][3] = 0x25872203a4f758683389ff32892b5a81f77f3c6f67cbb354de24faa5ffa0eb02;
        proofs[1][4] = 0xceabfa35664204de54bef98462c5cb9b226269f7cd7ebb26dbe8ebe360ecd67e;
        proofs[1][5] = 0x728dc13e6d7380e3b89c93a2884e80f0f0372d61243c2e07196cf6403fe0670d;
        proofs[1][6] = 0x6d3d9a6ddd979e25051f832a58f2c5ce894c634b612e4e61305633f540b31db5;
        proofs[1][7] = 0xb3f88e0e6ae307ec3c98a512f53ecf9318562b7bb4f611df0873ace3b632bacf;
        proofs[1][8] = 0x82b1c5c8130473a70f8cbe0e978c4ad7c2b55a3785e48594480b1147d5ed37bc;
        proofs[1][9] = 0xe5cc7e47e87031168d62e03e267077f9d56260d858158d697b5e69f8b0947d14;
        proofs[1][10] = 0xbe6f8be15da952384fa41ddd3e3d801de82c0b9bd320fb3c2eaaa71d3de129e8;
        proofs[1][11] = 0x536ecd45331e79725299ba47dba1998d248cf61108f31545e3ee7c2d1ef27acc;
        proofs[1][12] = 0x3fdb765abbe11e899f5c56b51ead895fb5df8845f250aca5b354e1bd91403648;
        proofs[1][13] = 0x3688bbfa9f9752e6440618eb438ce511615790cadacc7fc5427eb9d3fa798a24;
        proofs[1][14] = 0x2528840cfb204c7bb0c09e72548b05f18acf666e694af46e601e377aee717f67;
        proofs[1][15] = 0x062adfd1058164fecf1c51f6dcb1e3d0f76aab49889aadb1a74f7eb7fcbb402f;

        return proofs;
    }

    function test_claimMerklRewards_success() external {
        uint256 wsBalanceBefore = ws.balanceOf(address(yelayLiteVault));

        vm.startPrank(owner);
        yelayLiteVault.claimMerklRewards(_getTokens(), _getAmounts(), _getProofs());
        vm.stopPrank();

        assertEq(ws.balanceOf(address(yelayLiteVault)), wsBalanceBefore + 2066015760186535436007);
    }

    function test_claimMerklRewards_unauthorized() external {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, LibRoles.FUNDS_OPERATOR
            )
        );
        yelayLiteVault.claimMerklRewards(_getTokens(), _getAmounts(), _getProofs());
        vm.stopPrank();
    }

    function test_claimMerklRewards_invalidProof() external {
        vm.startPrank(owner);
        bytes32[][] memory invalidProofs = _getProofs();
        invalidProofs[0][0] = 0x000008f63230ddb1f7b0810a0f3fd71226bea79377bf7ab0f8a5ea72fd670000;

        vm.expectRevert();
        yelayLiteVault.claimMerklRewards(_getTokens(), _getAmounts(), invalidProofs);
        vm.stopPrank();
    }
}
