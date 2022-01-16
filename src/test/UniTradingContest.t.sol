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
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
}

contract DummySwap is ISwapRouter {


    function exactInputSingle(ExactInputSingleParams calldata params) override external payable returns (uint256 amountOut) {
        amountOut = params.amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) override external payable returns (uint256 amountOut) {
        amountOut = 0;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) override external payable returns (uint256 amountIn){
        amountIn = params.amountInMaximum;
    }

    function exactOutput(ExactOutputParams calldata params) override external payable returns (uint256 amountIn) {
        amountIn = 0;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) override external {}


}

contract UniTradingContestTestEnterContest is DSTest {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    UniTradingContest contest;
    MockERC20 usdc;
    uint32 constant START_BLOCK = 5;
    uint32 constant END_BLOCK = 100;
    uint128 constant ENTRY_FEE = 1300e18;
    uint128 constant PRIZE_TAKE_PER_ENTRY = 100e18;
    uint128 constant DAO_TAKE_PER_ENTRY = 100e18;
    uint128 constant CREATOR_TAKE_PER_ENTRY = 100e18;
    address constant creator = address(0x111);
    string contestName = "Great Contest";

    function setUp() public {
        ISwapRouter router = new DummySwap();
        usdc = new MockERC20("Mock USDC", "USDC");

        contest = new UniTradingContest(
            START_BLOCK,
            END_BLOCK,
            ENTRY_FEE,
            PRIZE_TAKE_PER_ENTRY,
            DAO_TAKE_PER_ENTRY,
            CREATOR_TAKE_PER_ENTRY,
            creator,
            usdc,
            router,
            contestName
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
        assertEq(contest.scores().length, 1);
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

contract UniTradingContestTest is DSTest {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    UniTradingContest contest;
    MockERC20 usdc = new MockERC20("Mock USDC", "USDC");
    ERC20 constant WETH = ERC20(5);
    uint32 constant START_BLOCK = 5;
    uint32 constant END_BLOCK = 100;
    uint128 constant ENTRY_FEE = 1300e18;
    uint128 constant PRIZE_TAKE_PER_ENTRY = 100e18;
    uint128 constant DAO_TAKE_PER_ENTRY = 100e18;
    uint128 constant CREATOR_TAKE_PER_ENTRY = 100e18;
    address constant competitor1 = address(1);
    address constant competitor2 = address(2);
    address constant competitor3 = address(3);

    function setUp() public {
        ISwapRouter router = new DummySwap();
        
        contest = new UniTradingContest(
            START_BLOCK,
            END_BLOCK,
            ENTRY_FEE,
            PRIZE_TAKE_PER_ENTRY,
            DAO_TAKE_PER_ENTRY,
            CREATOR_TAKE_PER_ENTRY,
            address(0),
            usdc,
            router,
            "contest"
        );

        enterContest(competitor1);
        enterContest(competitor2);
        enterContest(competitor3);

        vm.roll(START_BLOCK);
    }

    function testExactInputSingle() public {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(usdc),
            tokenOut: address(WETH),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 15,
            amountIn: 1e18,
            amountOutMinimum: 1e16,
            sqrtPriceLimitX96: 0
        });
        vm.prank(competitor1);
        contest.exactInputSingle(params);
        assertEq(contest.currentWinner().id, competitor1);
        assertEq(contest.currentWinner().priority, 999e18);
        assertEq(contest.balanceOf(address(usdc), competitor1), 999e18);
        assertEq(contest.balanceOf(address(WETH), competitor1), 1e16);
    }

    function testExactOutputSingle() public {
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(usdc),
            tokenOut: address(WETH),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 15,
            amountOut: 1e16,
            amountInMaximum: 1e18,
            sqrtPriceLimitX96: 0
        });
        vm.prank(competitor1);
        contest.exactOutputSingle(params);
        assertEq(contest.currentWinner().id, competitor1);
        assertEq(contest.currentWinner().priority, 999e18);
        assertEq(contest.balanceOf(address(usdc), competitor1), 999e18);
        assertEq(contest.balanceOf(address(WETH), competitor1), 1e16);
    }

    function testMultipleCompetitors() public {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(usdc),
            tokenOut: address(WETH),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 15,
            amountIn: 1e18,
            amountOutMinimum: 1e16,
            sqrtPriceLimitX96: 0
        });
        vm.prank(competitor1);
        contest.exactInputSingle(params);
        assertEq(contest.currentWinner().id, competitor1);

        params.amountIn = 1e17;
        vm.prank(competitor2);
        contest.exactInputSingle(params);
        assertEq(contest.currentWinner().id, competitor2);

        ISwapRouter.ExactOutputSingleParams memory outParams = ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(usdc),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 15,
            amountOut: 1e18,
            amountInMaximum: 1e16,
            sqrtPriceLimitX96: 0
        });
        vm.prank(competitor1);
        contest.exactOutputSingle(outParams);
        assertEq(contest.currentWinner().id, competitor1); 
    }


    // HELPERS

    function enterContest(address account) public {
        usdc.mint(address(account), ENTRY_FEE);
        vm.startPrank(account);
        usdc.approve(address(contest), ENTRY_FEE);
        contest.enterContest();
        vm.stopPrank();
    }
}

// contest over tests 
// dao withdrawal

// creator withdrawal

// prize withdrawal 