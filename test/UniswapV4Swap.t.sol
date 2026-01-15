// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {UniswapV4Swapper} from "../src/uniswapv4/UniV4Swap.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

contract UniswapV4SwapperTest is Test {
    UniswapV4Swapper swapper;
    
    address constant UNIVERSAL_ROUTER = 0x6fF5693b99212Da76ad316178A184AB56D299b43;
    address constant POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    
    function setUp() public {
        // Fork Base mainnet
        vm.createSelectFork("https://base-mainnet.g.alchemy.com/v2/9YjAHQZxzXZC6robpxM4XlWj0XRmRaN0");
        
        // Deploy swapper
        swapper = new UniswapV4Swapper(UNIVERSAL_ROUTER, POOL_MANAGER, PERMIT2);
    }
    
    function testPoolNotInitialized() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(0xFCa95aeb5bF44aE355806A5ad14659c940dC6BF7),
            fee: 3000,
            tickSpacing: 398,
            hooks: IHooks(address(0))
        });
        
        // This should revert with PoolNotInitialized
        vm.expectRevert();
        swapper.swapExactInputSingle{value: 0.1 ether}(
            key,
            true,
            0.1 ether,
            0,
            block.timestamp + 300
        );
    }
}
