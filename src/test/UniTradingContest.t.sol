// SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;
pragma abicoder v2;

import "ds-test/test.sol";
import "../UniTradingContest.sol";
import {MockERC20} from "./MockERC20.sol";
import {SwapRouter} from 'v3-periphery/SwapRouter.sol';
import {ISwapRouter} from 'v3-periphery/interfaces/ISwapRouter.sol';

interface Vm {
    function roll(uint256) external;
    function expectRevert(bytes calldata) external;
    function etch(address, bytes calldata) external;
}

contract UniTradingContestTest is DSTest {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    UniTradingContest contest;
    MockERC20 usdc;
    uint32 constant START_BLOCK = 5;
    uint32 constant END_BLOCK = 100;
    uint128 constant ENTRY_FEE = 1300e18;
    uint128 constant PRIZE_TAKE_PER_ENTRY = 100e18;
    uint128 constant DAO_TAKE_PER_ENTRY = 100e18;
    uint128 constant CREATOR_TAKE_PER_ENTRY = 100e18;

    function setUp() public {
        SwapRouter router;
        usdc = new MockERC20("Mock USDC", "USDC");

        contest = new UniTradingContest(
            START_BLOCK,
            END_BLOCK,
            usdc,
            ENTRY_FEE,
            PRIZE_TAKE_PER_ENTRY,
            DAO_TAKE_PER_ENTRY,
            CREATOR_TAKE_PER_ENTRY,
            router
        );

        vm.roll(START_BLOCK - 1);
    }

    // enterContest
    function testEnterContestBalance() public {
        enterContest();
        assertEq(contest.contestantStartAmount(), contest.balanceOf(address(usdc), address(this)));
    }

    function testEnterContestContestants() public {
        enterContest();
        assertEq(1, uint(contest.contestants()));
    }

    function testEnterContestPrize() public {
        enterContest();
        assertEq(uint(contest.prize()), uint(PRIZE_TAKE_PER_ENTRY));
    }

    function testEnterContestDaoFees() public {
        enterContest();
        assertEq(uint(DAO_TAKE_PER_ENTRY), uint(contest.daoFees()));
    }

    function testEnterContesScores() public {
        enterContest();
        assertEq(contest.scores()[0].id, address(0));
    }

    function testEnterContestAfterStarted() public {
        vm.roll(START_BLOCK);
        vm.expectRevert("contest started");
        contest.enterContest();
    }

    function testAlreadyEnteredContest() public {
        enterContest();
        usdc.mint(address(this), ENTRY_FEE);
        usdc.approve(address(contest), ENTRY_FEE);
        vm.expectRevert('already entered');
        contest.enterContest();
    }

    function testEnterContestNotApproved() public {
        usdc.mint(address(this), ENTRY_FEE);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        contest.enterContest();
    }

    // HELPERS

    function enterContest() public {
        usdc.mint(address(this), ENTRY_FEE);
        usdc.approve(address(contest), ENTRY_FEE);
        contest.enterContest();
    }
}