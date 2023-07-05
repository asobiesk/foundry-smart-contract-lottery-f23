//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {Raffle} from "../src/Raffle.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .networkActiveConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on chain: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Interface(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("sub id is: ", subId);
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address linkTokenAddress,
            uint256 deployerKey
        ) = helperConfig.networkActiveConfig();
        fundSubscription(
            vrfCoordinator,
            subscriptionId,
            linkTokenAddress,
            deployerKey
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address linkTokenAddress,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription ", subId);
        console.log("VRF Coordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        if (block.chainid == 31337) {
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
        } else {
            LinkToken(linkTokenAddress).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
        }
        vm.stopBroadcast();
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address raffleAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.networkActiveConfig();
        addConsumer(vrfCoordinator, subId, raffleAddress, deployerKey);
    }

    function addConsumer(
        address vrfCoordinator,
        uint64 subId,
        address raffle,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer", raffle);
        console.log("VRF Coordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Interface(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address raffleAddress = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffleAddress);
    }
}
