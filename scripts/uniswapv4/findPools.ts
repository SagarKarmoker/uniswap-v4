import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

const RPC_URL = process.env.FORK_RPC_URL || "http://localhost:8545";

// Contract addresses on Base
const POOL_MANAGER = "0x498581fF718922c3f8e6A244956aF099B2652b2b";
const UNIVERSAL_ROUTER = "0x6fF5693b99212Da76ad316178A184AB56D299b43";
const QUOTER = "0x0d5e0f971ed27fbff6c2837bf31316121532048d";

const QUOTER_ABI = [
  "function quoteExactInputSingle((tuple(address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks) poolKey, bool zeroForOne, uint128 exactAmount, bytes hookData)) external returns (uint256 amountOut, uint256 gasEstimate)"
];

async function testPoolExists(provider: any, poolKey: any, tokenSymbol: string, decimals: number) {
  console.log(`\n🔍 Testing ${tokenSymbol} pool...`);
  
  const quoter = new ethers.Contract(QUOTER, QUOTER_ABI, provider);
  
  try {
    // Try to get a quote for 0.01 ETH
    const result = await (quoter as any).quoteExactInputSingle.staticCall({
      poolKey,
      zeroForOne: true,
      exactAmount: ethers.parseEther("0.01"),
      hookData: "0x"
    });
    
    console.log(`✅ ${tokenSymbol} pool EXISTS!`);
    console.log(`   Quote: 0.01 ETH → ${ethers.formatUnits(result[0], decimals)} ${tokenSymbol}`);
    console.log(`   Gas estimate: ${result[1].toString()}`);
    return true;
  } catch (error: any) {
    if (error.message.includes("PoolNotInitialized") || error.data?.includes("486aa307")) {
      console.log(`❌ ${tokenSymbol} pool does NOT exist - PoolNotInitialized`);
    } else {
      console.log(`❌ ${tokenSymbol} error:`, error.message.split('\n')[0]);
    }
    return false;
  }
}

async function main() {
  console.log("🔍 Searching for Uniswap V4 Pools on Base...\n");

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  
  // Check if contracts exist
  const pmCode = await provider.getCode(POOL_MANAGER);
  const urCode = await provider.getCode(UNIVERSAL_ROUTER);
  const quoterCode = await provider.getCode(QUOTER);
  
  console.log("✅ PoolManager exists:", pmCode.length > 2);
  console.log("✅ UniversalRouter exists:", urCode.length > 2);
  console.log("✅ Quoter exists:", quoterCode.length > 2);
  
  // Test various popular pools
  const poolsToTest = [
    {
      name: "ETH/USDC (0.3%)",
      poolKey: {
        currency0: "0x0000000000000000000000000000000000000000",
        currency1: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        fee: 3000,
        tickSpacing: 60,
        hooks: "0x0000000000000000000000000000000000000000"
      },
      decimals: 6
    },
    {
      name: "ETH/USDC (0.05%)",
      poolKey: {
        currency0: "0x0000000000000000000000000000000000000000",
        currency1: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        fee: 500,
        tickSpacing: 10,
        hooks: "0x0000000000000000000000000000000000000000"
      },
      decimals: 6
    },
    {
      name: "ETH/DAI",
      poolKey: {
        currency0: "0x0000000000000000000000000000000000000000",
        currency1: "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb",
        fee: 3000,
        tickSpacing: 60,
        hooks: "0x0000000000000000000000000000000000000000"
      },
      decimals: 18
    },
    {
      name: "ETH/SHIB",
      poolKey: {
        currency0: "0x0000000000000000000000000000000000000000",
        currency1: "0xfca95aeb5bf44ae355806a5ad14659c940dc6bf7",
        fee: 3000,
        tickSpacing: 398,
        hooks: "0x0000000000000000000000000000000000000000"
      },
      decimals: 9
    }
  ];

  let foundPools: any[] = [];
  for (const pool of poolsToTest) {
    const exists = await testPoolExists(provider, pool.poolKey, pool.name, pool.decimals);
    if (exists) {
      foundPools.push(pool);
    }
  }

  console.log("\n" + "=".repeat(60));
  if (foundPools.length > 0) {
    console.log(`✅ FOUND ${foundPools.length} WORKING POOL(S)!\n`);
    foundPools.forEach((pool, i) => {
      console.log(`Pool ${i + 1}: ${pool.name}`);
      console.log(JSON.stringify(pool.poolKey, null, 2));
      console.log();
    });
  } else {
    console.log("❌ NO V4 POOLS FOUND ON BASE MAINNET");
    console.log("\n💡 SOLUTIONS:");
    console.log("   1. Initialize a new pool using PositionManager");
    console.log("   2. Test on Base Sepolia testnet where pools exist");
    console.log("   3. Wait for more liquidity providers to create V4 pools on Base");
  }
  console.log("=".repeat(60) + "\n");
}

main().catch(console.error);
