// // SPDX-License-Identifier: Unlicense
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

// These tests are expected to be run against live network state
// Run with `forge test -f <json rpc URI>`
contract UniTradingContestLiveTest is DSTest {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    UniTradingContest contest;
    MockERC20 usdc;
    // mainnet swap router, useful for running tests with fork against
    // mainnet, so we do not have to setup all uniswap stuff
    SwapRouter router = SwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint32 constant START_BLOCK = 14000000;
    uint32 constant END_BLOCK = 14001000;
    uint128 constant ENTRY_FEE = 1300e18;
    uint128 constant PRIZE_TAKE_PER_ENTRY = 100e18;
    uint128 constant DAO_TAKE_PER_ENTRY = 100e18;
    uint128 constant CREATOR_TAKE_PER_ENTRY = 100e18;
    ERC20 constant WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        MockERC20 mock = new MockERC20("Mock USDC", "USDC");
        // etch our mock USDC to the real USDC 
        vm.etch(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), getCode(address(mock)));
        usdc = MockERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

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

        vm.roll(START_BLOCK - 1);
        // pool gets deployed on the first swap, 
        // do it here so that pool deploy cost doesn't
        // muddy gas cost of other tests
        dummySwap();
    }

    function testExactInputSingle() public {
        enterContest(address(this));

        vm.roll(START_BLOCK);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(usdc),
            tokenOut: address(WETH),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 15,
            amountIn: 1e18,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        contest.exactInputSingle(params);
        
        assertGt(contest.balanceOf(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), address(this)), 0);
        assertEq(contest.balanceOf(address(usdc), address(this)), 999e18);
        assertEq(contest.scores()[1].id, address(this));
        assertEq(contest.currentWinner().id, address(this));
    }

    function dummySwap() public {
        address a = address(1);
        usdc.mint(a, 1e18);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(usdc),
            tokenOut: address(WETH),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 15,
            amountIn: 1e18,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        vm.startPrank(a);
        usdc.approve(address(router), 1e18);
        router.exactInputSingle(params);
        vm.stopPrank();
    }

    function enterContest(address account) public {
        usdc.mint(account, ENTRY_FEE);
        vm.startPrank(account);
        usdc.approve(address(contest), ENTRY_FEE);
        contest.enterContest();
        vm.stopPrank();
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
