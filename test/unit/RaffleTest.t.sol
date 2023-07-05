//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    /* Possibly redundant in 0.8.21 */
    event EnteredRaffle(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event PickedWinner(address indexed winner);

    Raffle raffle;
    HelperConfig helperConfig;
    address public PLAYER = makeAddr("Player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkTokenAddress;

    modifier readyForResult() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            linkTokenAddress,

        ) = helperConfig.networkActiveConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /* 
        enterRaffle()
    */

    function testEnterRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughMoney.selector);
        raffle.enterRaffle{value: 0 ether}();
    }

    function testEnterRaffleRecordsPlayerWhenTheyEntered() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getPlayer(0), address(PLAYER));
    }

    function testEnterRaffleEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testEnterRaffleRevertsWhenRaffleIsCalculating()
        public
        readyForResult
    {
        raffle.pickWinner();
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /* 
        canIPickWinner()
    */

    function testCanIPickWinnerReturnsFalseWhenTimeHasNotPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.canIPickWinner(), false);
    }

    function testCanIPickWinnerReturnsFalseWhenNoPlayersEntered() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        assertEq(raffle.canIPickWinner(), false);
    }

    function testCanIPickWinnerReturnsFalseWhenRaffleIsNotOpen()
        public
        readyForResult
    {
        raffle.pickWinner();
        assertEq(raffle.canIPickWinner(), false);
    }

    function testCanIPickWinnerReturnsTrueWhenAllConditionsAreMet()
        public
        readyForResult
    {
        assertEq(raffle.canIPickWinner(), true);
    }

    /* 
        pickWinner()
    */

    function testPickWinnerRevertsIfConditionsAreNotMet() public {
        vm.expectRevert(Raffle.Raffle__WinnerPickingConditionsNotMet.selector);
        raffle.pickWinner();
    }

    function testPickWinnerChangesRaffleStateToCalculating()
        public
        readyForResult
    {
        raffle.pickWinner();
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    function testPickWinnerEmitsRequestEvent() public readyForResult {
        vm.recordLogs();
        raffle.pickWinner();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        assert(uint256(requestId) > 0);
    }

    /* 
        fulfillRandomWords()
    */

    function testFulfillRandomWordsCanOnlyBeCalledAfterPickWinner(
        uint256 randomRequestId
    ) public skipFork readyForResult {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsEth()
        public
        readyForResult
        skipFork
    {
        uint256 additionalPlayers = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalPlayers;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = additionalPlayers * entranceFee;

        vm.recordLogs();
        raffle.pickWinner();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        vm.recordLogs();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        Vm.Log[] memory entriesForWinnerPicking = vm.getRecordedLogs();
        bytes32 winnerFromEvent = entriesForWinnerPicking[0].topics[1];

        address recentWinner = raffle.getRecentWinner();

        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(recentWinner != address(0));
        assert(recentWinner == address(uint160(uint256(winnerFromEvent))));
        assertEq(raffle.getNumberOfPlayers(), 0);
        assertEq(raffle.getLastTimestamp(), block.timestamp);
        assertEq(address(raffle).balance, 0);
        assert(recentWinner.balance == STARTING_USER_BALANCE + prize);
    }
}
