// SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;

import "ds-test/test.sol";
import "../UniTradingContest.sol";
import {MockERC20} from "./MockERC20.sol";
import {SwapRouter} from 'v3-periphery/SwapRouter.sol';

interface Vm {
    function roll(uint256) external;
}

contract UniTradingContestTest is DSTest {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    UniTradingContest contest;
    MockERC20 usdc;
    SwapRouter router;

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "USDC");
        contest = new UniTradingContest(
            5,
            1000,
            usdc,
            1200e18,
            100e18,
            100e18,
            router
        );
    }

    function testEnterContest() public {
        usdc.mint(address(this), 1200e18);
        usdc.approve(address(contest), 1200e18);
        contest.enterContest();
        assertEq(1000e18, contest.balanceOf(address(usdc), address(this)));
    }
}
