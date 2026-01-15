import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

const RPC_URL = process.env.FORK_RPC_URL || "http://localhost:8545";
const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY!;

// Contract addresses on Base
const SWAPPER_ADDRESS = "0xDF9a2f5152c533F7fcc3bAdEd41e157C9563C695";
const WETH_ADDRESS = "0x4200000000000000000000000000000000000006"; // WETH on Base
const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"; // USDC on Base

// Pool configuration - using EXISTING ETH/USDC pool on Base!
const POOL_KEY = {
  currency0: "0x0000000000000000000000000000000000000000", // ETH (native)
  currency1: USDC_ADDRESS, // USDC
  fee: 3000, // 0.3%
  tickSpacing: 60,
  hooks: "0x0000000000000000000000000000000000000000", // No hooks
};

const SWAPPER_ABI = [
  "function swapExactInputSingle(tuple(address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks) key, bool zeroForOne, uint128 amountIn, uint128 amountOutMinimum, uint256 deadline) external payable returns (uint256 amountOut)",
  "function approveTokenWithPermit2(address token, uint160 amount, uint48 expiration) external",
  "function withdrawToken(address token, uint256 amount) external",
  "function withdrawETH(uint256 amount) external",
];

const ERC20_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function balanceOf(address account) external view returns (uint256)",
  "function transfer(address to, uint256 amount) external returns (bool)",
];

async function main() {
  try {
    console.log("🚀 Starting Uniswap V4 Swap Test");

    // Setup provider and signer
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const signer = new ethers.Wallet(DEPLOYER_PRIVATE_KEY, provider);

    console.log("📍 Using account:", signer.address);

    // Get contract instances
    const swapper = new ethers.Contract(SWAPPER_ADDRESS, SWAPPER_ABI, signer);
    const usdc = new ethers.Contract(USDC_ADDRESS, ERC20_ABI, signer);

    // Check balances before swap
    const ethBalance = await provider.getBalance(signer.address);
    const usdcBalance = await (usdc as any).balanceOf(signer.address);

    console.log("💰 Balances before swap:");
    console.log(`   ETH: ${ethers.formatEther(ethBalance)}`);
    console.log(`   USDC: ${ethers.formatUnits(usdcBalance, 6)}`);

    // Perform the swap: 0.01 ETH to USDC (should get ~33 USDC based on quote)
    const amountIn = ethers.parseEther("1");
    const amountOutMinimum = ethers.parseUnits("30", 6); // Expect at least 30 USDC
    const deadline = Math.floor(Date.now() / 1000) + 60 * 10; // 10 minutes from now

    console.log("🔄 Executing swap: 0.01 ETH to USDC");

    const tx = await (swapper as any).swapExactInputSingle(
      POOL_KEY,
      true, // zeroForOne: ETH to USDC
      amountIn,
      amountOutMinimum,
      deadline,
      { value: amountIn }
    );
    
    console.log("⏳ Waiting for transaction confirmation...");
    const receipt = await tx.wait();
    console.log("✅ Swap executed in transaction:", receipt.transactionHash);

    // Check balances after swap
    const ethBalanceAfter = await provider.getBalance(signer.address);
    const usdcBalanceAfter = await (usdc as any).balanceOf(signer.address);
    
    console.log("💰 Balances after swap:");
    console.log(`   ETH: ${ethers.formatEther(ethBalanceAfter)}`);
    console.log(`   USDC: ${ethers.formatUnits(usdcBalanceAfter, 6)}`);
    
    const usdcReceived = usdcBalanceAfter - usdcBalance;
    console.log(`\n📊 Result: Received ${ethers.formatUnits(usdcReceived, 6)} USDC for 0.01 ETH`);
  } catch (error) {
    console.error("❌ An error occurred:", error);
  }
}

main().catch(console.error);
