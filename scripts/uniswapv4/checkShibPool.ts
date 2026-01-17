import { ethers } from "ethers";

const RPC_URL = "http://localhost:8545";
const QUOTER_ADDRESS = "0x0d5e0f971ed27fbff6c2837bf31316121532048d";

const QUOTER_ABI = [
  "function quoteExactInputSingle((address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks) poolKey, bool zeroForOne, uint128 exactAmountIn) external returns (uint256 amountOut, uint256 gasEstimate)"
];

async function checkPool() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  
  const poolKey = {
    currency0: ethers.ZeroAddress,
    currency1: "0xfca95aeb5bf44ae355806a5ad14659c940dc6bf7",
    fee: 19900,
    tickSpacing: 398,
    hooks: ethers.ZeroAddress
  };

  const quoter = new ethers.Contract(QUOTER_ADDRESS, QUOTER_ABI, provider);

  console.log("Testing ETH → SHIB (zeroForOne = true):");
  try {
    const result1 = await quoter.quoteExactInputSingle.staticCall(
      poolKey,
      true,
      ethers.parseEther("0.001")
    );
    console.log("✅ ETH → SHIB works");
    console.log(`Output: ${ethers.formatUnits(result1[0], 9)} SHIB`);
  } catch (e: any) {
    console.log("❌ ETH → SHIB failed:", e.message);
  }

  console.log("\nTesting SHIB → ETH (zeroForOne = false):");
  try {
    const result2 = await quoter.quoteExactInputSingle.staticCall(
      poolKey,
      false,
      ethers.parseUnits("100", 9)
    );
    console.log("✅ SHIB → ETH works");
    console.log(`Output: ${ethers.formatEther(result2[0])} ETH`);
  } catch (e: any) {
    console.log("❌ SHIB → ETH failed:", e.message);
    console.log("Error code:", e.data);
  }
}

checkPool().catch(console.error);
