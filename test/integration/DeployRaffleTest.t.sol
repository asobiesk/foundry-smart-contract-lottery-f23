//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract DeployRaffleTest is Test {
    function setUp() external {}

    function testDeployRaffleCorrectlyDeploysTheRaffle() public {
        DeployRaffle deployer = new DeployRaffle();
        (Raffle raffle, HelperConfig helperConfig) = deployer.run();
        assert(uint160(address(raffle)) > 0);
        assert(uint160(address(helperConfig)) > 0);
    }
}
