// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.0;


// import {UniswapV3FlashLoan} from "../../src/flashloan/UniswapV3FlashLoan.sol";
// import "forge-std/Script.sol";

// contract UniswapV3FlashLoanScript is Script {
//     function run() external {
//         address poolAddress = vm.envAddress("POOL_ADDRESS");
//         address uniRouter = vm.envAddress("UNI_ROUTER");
//         address sushiRouter = vm.envAddress("SUSHI_ROUTER");

//         UniswapV3FlashLoan flashLoan = new UniswapV3FlashLoan(
//             poolAddress,
//             uniRouter,
//             sushiRouter
//         );
//         flashLoan.executeFlashLoan(poolAddress);
//     }
// }