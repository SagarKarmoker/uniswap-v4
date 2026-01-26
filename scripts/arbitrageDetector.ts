import { ethers } from 'ethers';

// Base mainnet RPC
const RPC_URL = 'https://base-rpc.publicnode.com';

// Contract addresses
const UNISWAP_QUOTER = '0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a';
const AERODROME_FACTORY = '0x420DD381b31aEf6683db6B902084cB0FFECe40Da';

// Tokens
const WETH_ADDRESS = '0x4200000000000000000000000000000000000006';
const USDC_ADDRESS = '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';

// Aerodrome Pair ABI (simplified)
const PAIR_ABI = [
  'function getReserves() view returns (uint112, uint112, uint32)',
  'function token0() view returns (address)',
  'function token1() view returns (address)'
];

async function getUniswapV3Price(tokenIn: string, tokenOut: string, amountIn: string): Promise<string> {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  
  // For simplicity, we'll use a direct quote. In production, you'd need pool data
  // This is a simplified version - you'd need to fetch pool state
  
  const quoterContract = new ethers.Contract(UNISWAP_QUOTER, [
    'function quoteExactInputSingle((address tokenIn, address tokenOut, uint256 amountIn, uint24 fee, uint160 sqrtPriceLimitX96) params) external view returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)'
  ], provider);

  try {
    // Using 0.3% fee tier
    const params = {
      tokenIn: ethers.getAddress(tokenIn),
      tokenOut: ethers.getAddress(tokenOut),
      amountIn: amountIn,
      fee: 3000,
      sqrtPriceLimitX96: 0
    };
    const [amountOut] = await quoterContract.quoteExactInputSingle(params);
    return amountOut.toString();
  } catch (error) {
    console.error('Error getting Uniswap price:', error);
    return '0';
  }
}

async function getAerodromePrice(tokenA: string, tokenB: string, amountIn: string): Promise<string> {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  
  const factoryContract = new ethers.Contract(AERODROME_FACTORY, [
    'function getPool(address tokenA, address tokenB, bool stable) view returns (address)'
  ], provider);

  try {
    const pairAddress = await factoryContract.getPool(tokenA, tokenB, false);
    if (pairAddress === ethers.ZeroAddress) {
      return '0';
    }

    const pairContract = new ethers.Contract(pairAddress, PAIR_ABI, provider);
    const [reserve0, reserve1] = await pairContract.getReserves();
    const token0 = await pairContract.token0();
    
    const reserveIn = token0 === tokenA ? BigInt(reserve0) : BigInt(reserve1);
    const reserveOut = token0 === tokenA ? BigInt(reserve1) : BigInt(reserve0);
    
    if (reserveIn === 0n || reserveOut === 0n) {
      return '0';
    }

    // Uniswap V2 formula
    const amountInBN = BigInt(amountIn);
    const numerator = amountInBN * reserveOut * 997n;
    const denominator = reserveIn * 1000n + amountInBN * 997n;
    const amountOut = numerator / denominator;
    
    return amountOut.toString();
  } catch (error) {
    console.error('Error getting Aerodrome price:', error);
    return '0';
  }
}

async function checkArbitrage() {
  const amountIn = ethers.parseUnits('1', 18); // 1 WETH
  
  console.log('Checking prices...');
  
  // Get prices
  const [uniswapPrice, aerodromePrice] = await Promise.all([
    getUniswapV3Price(WETH_ADDRESS, USDC_ADDRESS, amountIn.toString()),
    getAerodromePrice(WETH_ADDRESS, USDC_ADDRESS, amountIn.toString())
  ]);
  
  console.log(`Uniswap V3: 1 WETH = ${ethers.formatUnits(uniswapPrice, 6)} USDC`);
  console.log(`Aerodrome: 1 WETH = ${ethers.formatUnits(aerodromePrice, 6)} USDC`);
  
  const uniswapBN = BigInt(uniswapPrice);
  const aerodromeBN = BigInt(aerodromePrice);
  
  if (uniswapBN == 0n) {
    console.log('Uniswap price fetch failed, skipping arbitrage check');
    return;
  }
  
  if (uniswapBN > aerodromeBN) {
    const difference = uniswapBN - aerodromeBN;
    const percentage = (difference * 100n) / aerodromeBN;
    console.log(`🚨 Arbitrage opportunity: Uniswap is ${percentage.toString()}% higher`);
    console.log(`Price difference: ${ethers.formatUnits(difference, 6)} USDC`);
    console.log(`Buy on Aerodrome, sell on Uniswap`);
  } else if (aerodromeBN > uniswapBN) {
    const difference = aerodromeBN - uniswapBN;
    const percentage = (difference * 100n) / uniswapBN;
    console.log(`🚨 Arbitrage opportunity: Aerodrome is ${percentage.toString()}% higher`);
    console.log(`Price difference: ${ethers.formatUnits(difference, 6)} USDC`);
    console.log(`Buy on Uniswap, sell on Aerodrome`);
  } else {
    console.log('✅ Prices are aligned');
  }
}

// Run the detector
async function main() {
  console.log('Starting arbitrage detector...');
  
  // Check immediately
  await checkArbitrage();
  
  // Then check every 30 seconds
  setInterval(async () => {
    await checkArbitrage();
  }, 30000);
}

main().catch(console.error);