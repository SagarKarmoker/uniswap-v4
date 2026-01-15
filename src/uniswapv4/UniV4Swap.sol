// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IUniversalRouter} from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract UniswapV4Swapper is ReentrancyGuard {
    IUniversalRouter public immutable router;
    IPoolManager public immutable poolManager;
    IPermit2 public immutable permit2;
    address public owner;

    event SwapExecuted(address indexed poolKeyCurrency0, address indexed poolKeyCurrency1, uint256 amountIn, uint256 amountOut);
    event ApprovalDelegated(address indexed token, uint160 amount, uint48 expiration);

    error InsufficientOutputAmount();
    error DeadlinePassed();
    error TransferFailed();
    error InvalidPoolKey();

    constructor(
        address _router,
        address _poolManager,
        address _permit2
    ) {
        router = IUniversalRouter(_router);
        poolManager = IPoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
    }

    /// @notice Approves Permit2 and delegates to router for token spending
    function approveTokenWithPermit2(
        address token,
        uint160 amount,
        uint48 expiration
    ) external nonReentrant {
        // First approve Permit2 to spend tokens
        IERC20(token).approve(address(permit2), type(uint256).max);
        
        // Then approve router through Permit2
        permit2.approve(token, address(router), amount, expiration);
        
        emit ApprovalDelegated(token, amount, expiration);
    }

    /// @notice Swaps exact input amount for minimum output on a single V4 pool
    function swapExactInputSingle(
        PoolKey calldata key,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        uint256 deadline
    ) external payable nonReentrant returns (uint256 amountOut) {
        if (block.timestamp > deadline) revert DeadlinePassed();
        
        // Transfer input tokens from sender to this contract
        address tokenIn = zeroForOne ? Currency.unwrap(key.currency0) : Currency.unwrap(key.currency1);
        address tokenOut = zeroForOne ? Currency.unwrap(key.currency1) : Currency.unwrap(key.currency0);
        
        // Handle non-ETH input tokens
        if (tokenIn != address(0)) {
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
            IERC20(tokenIn).approve(address(router), amountIn);
        }

        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );
        
        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        
        // First parameter: swap configuration
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                hookData: bytes("")
            })
        );
        
        // Second parameter: specify input tokens for SETTLE_ALL
        params[1] = abi.encode(
            zeroForOne ? key.currency0 : key.currency1, 
            amountIn
        );
        
        // Third parameter: specify output tokens for TAKE_ALL
        params[2] = abi.encode(
            zeroForOne ? key.currency1 : key.currency0, 
            amountOutMinimum
        );

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap with deadline protection
        uint256 balanceBefore = tokenOut == address(0) 
            ? address(this).balance 
            : IERC20(tokenOut).balanceOf(address(this));
            
        router.execute{value: tokenIn == address(0) ? amountIn : 0}(commands, inputs, deadline);
        
        uint256 balanceAfter = tokenOut == address(0) 
            ? address(this).balance 
            : IERC20(tokenOut).balanceOf(address(this));

        // Verify and return the output amount
        amountOut = balanceAfter - balanceBefore;
        if (amountOut < amountOutMinimum) revert InsufficientOutputAmount();

        // Transfer output tokens to sender
        if (tokenOut == address(0)) {
            (bool success, ) = msg.sender.call{value: amountOut}("");
            if (!success) revert TransferFailed();
        } else {
            IERC20(tokenOut).transfer(msg.sender, amountOut);
        }

        emit SwapExecuted(
            Currency.unwrap(key.currency0), 
            Currency.unwrap(key.currency1), 
            amountIn, 
            amountOut
        );
    }

    /// @notice Withdraw ERC20 tokens from contract
    function withdrawToken(address token, uint256 amount) external nonReentrant {
        IERC20(token).transfer(msg.sender, amount);
    }

    /// @notice Withdraw ETH from contract
    function withdrawETH(uint256 amount) external nonReentrant {
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    receive() external payable {}
}