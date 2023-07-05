//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "../../src/Raffle.sol";

contract InteractionsTest is Test {
    CreateSubscription createSubscription;
    FundSubscription fundSubscription;
    AddConsumer addConsumer;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    address linkTokenAddress;
    uint256 deployerKey;

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        vm.allowCheatcodes(address(this));
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            ,
            linkTokenAddress,
            deployerKey
        ) = helperConfig.networkActiveConfig();
        vm.startBroadcast();
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        addConsumer = new AddConsumer();
        vm.stopBroadcast();
    }

    function testCreateSubscriptionCreatesSubscription() public skipFork {
        uint64 subId = createSubscription.run();
        assertEq(subId, 1);
    }

    function testFundSubsctiptionFundsSubscription() public skipFork {
        uint64 subId = createSubscription.createSubscription(
            vrfCoordinator,
            deployerKey
        );
        vm.recordLogs();
        fundSubscription.fundSubscription(
            vrfCoordinator,
            subId,
            linkTokenAddress,
            deployerKey
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 subIdFromEvent = entries[0].topics[1];
        assert(uint256(subIdFromEvent) == uint256(subId));
    }

    function testAddConsumerAddsConsumer() public skipFork {
        uint64 subId = createSubscription.createSubscription(
            vrfCoordinator,
            deployerKey
        );
        vm.recordLogs();
        addConsumer.addConsumer(
            vrfCoordinator,
            subId,
            address(this) /* Adding this test contract as a consumer */,
            deployerKey
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 subIdFromEvent = entries[0].topics[1];
        bytes32 consumerAddressFromEvent = bytes32(entries[0].data);
        assert(uint256(subIdFromEvent) == uint256(subId));
        assert(
            address(uint160(uint256(consumerAddressFromEvent))) == address(this)
        );
    }
}
