// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

library LibEvents {
    event Redeem();
}

library LibOwner {
    struct OwnerStorage {
        address owner;
        address pendingOwner;
        mapping(bytes4 => address) selectorToFacet;
    }

    bytes32 private constant OWNER_STORAGE_LOCATION = 0x52b130868e76fc87849159cef46eb9bb0156aa8877197d318e4437829044d000;

    function _getOwnerStorage() internal pure returns (OwnerStorage storage $) {
        assembly {
            $.slot := OWNER_STORAGE_LOCATION
        }
    }

    function onlyOwner() internal view {
        OwnerStorage storage s = _getOwnerStorage();
        require(s.owner == msg.sender);
    }
}

contract EventTest {
    event internEvent();

    struct OwnerStorage {
        address owner;
        address pendingOwner;
        mapping(bytes4 => address) selectorToFacet;
    }

    OwnerStorage public ownerStorage;

    function addOwner() public {
        ownerStorage.owner = msg.sender;
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        s.owner = msg.sender;
    }

    // modifier onlyOwner() {
    //     require(ownerStorage.owner == msg.sender);
    //     _;
    // }
    function onlyOwner() internal view {
        require(ownerStorage.owner == msg.sender);
    }

    function testEx() external {
        emit LibEvents.Redeem();
    }

    function testInt() external {
        emit internEvent();
    }

    // function callMe() external view onlyOwner {}
    function callMe() external view {
        onlyOwner();
    }

    function callMeToo() external view {
        LibOwner.onlyOwner();
    }
}

contract LibTest is Test {
    EventTest eventTest;

    function setUp() external {
        eventTest = new EventTest();
        eventTest.addOwner();
    }

    // 20_000 - 932
    // 200 - 976
    function test_gas_testEx() external {
        eventTest.testEx();
    }

    // 20_000 - 911
    // 200 - 888
    function test_gas_testInt() external {
        eventTest.testInt();
    }

    // 20_000 - 2294
    // 200 - 2350
    function test_gas_callMe() external view {
        eventTest.callMe();
    }

    // 20_000 - 2344
    // 200 - 2400
    function test_gas_callMeToo() external view {
        eventTest.callMeToo();
    }
}
