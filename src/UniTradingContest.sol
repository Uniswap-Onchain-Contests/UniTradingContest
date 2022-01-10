// SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;
pragma abicoder v2;

import {SafeMath} from 'openzeppelin-contracts/math/SafeMath.sol';
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/SafeERC20.sol";
import {ISwapRouter} from 'v3-periphery/interfaces/ISwapRouter.sol';
import {Heap} from './libraries/Heap.sol';

contract UniTradingContest {
    using Heap for Heap.Data;
    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeERC20 for ERC20;

    bool public prizeClaimed;
    uint32 public contestants;
    uint32 immutable public contestStartBlock;
    uint32 immutable public contestEndBlock;
    uint128 immutable public entryFee;
    uint128 immutable public prizeTakePerEntry;
    uint128 immutable public daoTakePerEntry;
    uint128 immutable public creatorTakePerEntry;
    uint128 immutable public contestantStartAmount;
    Heap.Data private _scoresHeap;
    ERC20 immutable public contestDenominationToken;
    ISwapRouter immutable _router;
    mapping(uint160 => uint256) private _balances;

    modifier contestLive() {
        require(contestStartBlock >= block.number 
        && block.number <= contestEndBlock, 'contest must be live');
        _;
    }

    function balanceOf(address asset, address account) public view returns(uint256){
        return _balances[assetAccountKey(asset, account)];
    }

    function assetAccountKey(address asset, address account) private pure returns(uint160){
        return uint160(asset) ^ uint160(account);
    }

    function scores() external view returns(Heap.Node[] memory){
        return _scoresHeap.nodes;
    }

    function currentWinner() external view returns(Heap.Node memory){
        return _scoresHeap.getMax();
    }

    constructor(
        uint32 _contestStartBlock,
        uint32 _contestEndBlock,
        ERC20 _contestDenominationToken,
        uint128 _entryFee,
        uint128 _prizeTakePerEntry,
        uint128 _daoTakePerEntry, 
        uint128 _creatorTakePerEntry,
        ISwapRouter _router_
    ) {
       contestStartBlock = _contestStartBlock;
       contestEndBlock = _contestEndBlock;
       contestDenominationToken = _contestDenominationToken;
       entryFee = _entryFee;
       prizeTakePerEntry = _prizeTakePerEntry;
       daoTakePerEntry = _daoTakePerEntry;
       creatorTakePerEntry = _creatorTakePerEntry;
       _router = _router_;
       uint128 startAmount = uint128(_entryFee.sub(_prizeTakePerEntry).sub(_daoTakePerEntry).sub(_creatorTakePerEntry));
       require(startAmount > 0);
       contestantStartAmount = startAmount;

       _scoresHeap.init();
    }

    function enterContest() external {
        require(block.number < contestStartBlock, 'contest started');
        require(balanceOf(address(contestDenominationToken), msg.sender) == 0, 'already entered');

        increaseBalance(
            address(contestDenominationToken),
            msg.sender,
            contestantStartAmount
        );
        contestants++;
        contestDenominationToken.safeTransferFrom(msg.sender, address(this), entryFee);
    }

    function updateScore(address account) private {
        if(_scoresHeap.getById(account).id != address(0)){
            _scoresHeap.extractById(account);
        }
        _scoresHeap.insert(account, balanceOf(address(contestDenominationToken), msg.sender));
    }

    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params) contestLive external {
        // TODO: somehow screen the pool being interacted with to 
        // disallow "cheating" with low liquidity pools"
        ERC20(params.tokenIn).approve(address(_router), type(uint256).max);
        decreaseBalance(params.tokenIn, msg.sender, params.amountIn);
        uint256 out = _router.exactInputSingle(params);
        increaseBalance(params.tokenOut, msg.sender, out);
        if(params.tokenIn == address(contestDenominationToken) || params.tokenOut == address(contestDenominationToken)){
            updateScore(msg.sender);
        }
    }

    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata params) contestLive external {
        // TODO: somehow screen the pool being interacted with to 
        // disallow "cheating" with low liquidity pools"
        uint256 amountIn = _router.exactOutputSingle(params);
        decreaseBalance(params.tokenIn, msg.sender, amountIn);
        increaseBalance(params.tokenOut, msg.sender, params.amountOut);

        if(params.tokenIn == address(contestDenominationToken) || params.tokenOut == address(contestDenominationToken)){
            updateScore(msg.sender);
        }
    }

    function withdraw(address asset, uint256 amount) external {
        decreaseBalance(asset, msg.sender, amount);
        contestDenominationToken.safeTransfer(msg.sender, amount);
    }

    function withdrawPrize() external {
        require(block.number > contestEndBlock, "contest not over");
        require(msg.sender == _scoresHeap.nodes[0].id, "not winner");
        require(!prizeClaimed, "prize claimed");
        prizeClaimed = true;
        contestDenominationToken.safeTransfer(msg.sender, prize());
    }

    function prize() public returns (uint128) {
        return contestants * prizeTakePerEntry;
    }

    function daoFees() public returns (uint128) {
        return contestants * daoTakePerEntry;
    }

    function creatorFees() public returns (uint128) {
        return contestants * creatorTakePerEntry;
    }

    function increaseBalance(address asset, address account, uint256 amount) private {
        _balances[assetAccountKey(asset, account)] += amount; 
    }

    function decreaseBalance(address asset, address account, uint256 amount) private {
        uint160 key = assetAccountKey(asset, account);
        _balances[key] = _balances[key].sub(amount);
    }
}
