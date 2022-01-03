// SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;
pragma abicoder v2;

import "ds-test/test.sol";
import "../UniTradingContest.sol";
import {MockERC20} from "./MockERC20.sol";
import {SwapRouter} from 'v3-periphery/SwapRouter.sol';
import {Quoter} from 'v3-periphery/lens/Quoter.sol';
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
    // mainnet swap router, useful for running tests with fork against
    // mainnet, so we do not have to setup all uniswap stuff
    SwapRouter router = SwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint32 startBlock = 14000000;
    uint32 endBlock = 14001000;
    uint128 entryFee = 1300e18;
    uint128 prizeTakePerEntry = 100e18;
    uint128 daoTakePerEntry = 100e18;
    uint128 creatorTakePerEntry = 100e18;

    function setUp() public {
        MockERC20 mock = new MockERC20("Mock USDC", "USDC");
        // etch our mock USDC to the real USDC 
        vm.etch(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), getCode(address(mock)));
        usdc = MockERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        contest = new UniTradingContest(
            startBlock,
            endBlock,
            usdc,
            entryFee,
            prizeTakePerEntry,
            daoTakePerEntry,
            creatorTakePerEntry,
            router
        );

        vm.roll(startBlock - 1);
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
        assertEq(uint(contest.prize()), uint(prizeTakePerEntry));
    }

    function testEnterContestDaoFees() public {
        enterContest();
        assertEq(uint(daoTakePerEntry), uint(contest.daoFees()));
    }

    function testEnterContesScores() public {
        enterContest();
        assertEq(contest.scores()[0].id, address(0));
    }

    function testEnterContestAfterStarted() public {
        vm.roll(startBlock);
        vm.expectRevert("contest started");
        contest.enterContest();
    }

    function testAlreadyEnteredContest() public {
        enterContest();
        usdc.mint(address(this), entryFee);
        usdc.approve(address(contest), entryFee);
        vm.expectRevert('already entered');
        contest.enterContest();
    }

    function testEnterContestNotApproved() public {
        usdc.mint(address(this), entryFee);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        contest.enterContest();
    }

    // swap
    function testExactInputSingle() public {
        enterContest();

        vm.roll(startBlock);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(usdc),
            tokenOut: address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // weth
            fee: 10000,
            recipient: address(this),
            deadline: block.timestamp + 15,
            amountIn: 1e18,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        contest.exactInputSingle(params);
        
        assertGt(contest.balanceOf(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), address(this)), 0);
        assertEq(contest.balanceOf(address(usdc), address(this)), 999e18);
        assertEq(contest.scores()[0].id, address(this));
    }

    // HELPERS

    function enterContest() public {
        usdc.mint(address(this), entryFee);
        usdc.approve(address(contest), entryFee);
        contest.enterContest();
    }

    function getCode(address who) internal returns (bytes memory o_code) {
        assembly {
            // retrieve the size of the code, this needs assembly
            let size := extcodesize(who)
            // allocate output byte array - this could also be done without assembly
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // store length in memory
            mstore(o_code, size)
            // actually retrieve the code, this needs assembly
            extcodecopy(who, add(o_code, 0x20), 0, size)
        }
    }
}
