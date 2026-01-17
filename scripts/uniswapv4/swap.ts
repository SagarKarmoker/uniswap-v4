import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

const RPC_URL = process.env.FORK_RPC_URL || "http://localhost:8545";
const PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY!;
const SWAPPER_ADDRESS = "0xDF9a2f5152c533F7fcc3bAdEd41e157C9563C695";

const SWAPPER_ABI = [
  "function swapExactInputSingle(tuple(address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks) key, bool zeroForOne, uint128 amountIn, uint128 amountOutMinimum, uint256 deadline) external payable returns (uint256 amountOut)",
];

const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
];

interface SwapConfig {
  poolKey: {
    currency0: string;
    currency1: string;
    fee: number;
    tickSpacing: number;
    hooks: string;
  };
  amountIn: string;
  zeroForOne?: boolean;
  slippagePercent?: number;
  deadlineMinutes?: number;
}

async function swap(config: SwapConfig) {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const signer = new ethers.Wallet(PRIVATE_KEY, provider);
  const swapper = new ethers.Contract(SWAPPER_ADDRESS, SWAPPER_ABI, signer);

  const zeroForOne = config.zeroForOne ?? true;
  const tokenIn = zeroForOne ? config.poolKey.currency0 : config.poolKey.currency1;
  const tokenOut = zeroForOne ? config.poolKey.currency1 : config.poolKey.currency0;
  const isETHInput = tokenIn === ethers.ZeroAddress;

  let tokenInDecimals = 18, tokenInSymbol = "ETH";
  let tokenOutDecimals = 18, tokenOutSymbol = "TOKEN";

  if (tokenIn !== ethers.ZeroAddress) {
    const tokenInContract = new ethers.Contract(tokenIn, ERC20_ABI, provider);
    tokenInDecimals = await tokenInContract.decimals();
    tokenInSymbol = await tokenInContract.symbol();
  }

  if (tokenOut !== ethers.ZeroAddress) {
    const tokenOutContract = new ethers.Contract(tokenOut, ERC20_ABI, provider);
    tokenOutDecimals = await tokenOutContract.decimals();
    tokenOutSymbol = await tokenOutContract.symbol();
  }

  const amountIn = ethers.parseUnits(config.amountIn, tokenInDecimals);

  // Approve if ERC20 input
  if (!isETHInput) {
    const tokenInContract = new ethers.Contract(tokenIn, [...ERC20_ABI, "function approve(address,uint256) returns (bool)"], signer);
    const approveTx = await tokenInContract.approve(SWAPPER_ADDRESS, amountIn);
    await approveTx.wait();
    console.log(`✅ Approved ${config.amountIn} ${tokenInSymbol}`);
  }

  const balanceBefore =
    tokenOut === ethers.ZeroAddress
      ? await provider.getBalance(signer.address)
      : await new ethers.Contract(tokenOut, ERC20_ABI, provider).balanceOf(signer.address);

  console.log(
    `💰 Before: ${ethers.formatUnits(balanceBefore, tokenOutDecimals)} ${tokenOutSymbol}`
  );

  const deadline =
    Math.floor(Date.now() / 1000) + (config.deadlineMinutes || 10) * 60;

  console.log(
    `🔄 Swapping ${config.amountIn} ${tokenInSymbol} → ${tokenOutSymbol}...`
  );

  const tx = await swapper.swapExactInputSingle(
    config.poolKey,
    zeroForOne,
    amountIn,
    0,
    deadline,
    { value: isETHInput ? amountIn : 0 }
  );
  const receipt = await tx.wait();
  console.log(`✅ Tx: ${receipt.hash}`);

  const balanceAfter =
    tokenOut === ethers.ZeroAddress
      ? await provider.getBalance(signer.address)
      : await new ethers.Contract(tokenOut, ERC20_ABI, provider).balanceOf(
          signer.address
        );

  const received = balanceAfter - balanceBefore;
  console.log(
    `💰 After: ${ethers.formatUnits(
      balanceAfter,
      tokenOutDecimals
    )} ${tokenOutSymbol}`
  );
  console.log(
    `📊 Received: ${ethers.formatUnits(
      received,
      tokenOutDecimals
    )} ${tokenOutSymbol}\n`
  );
}

async function main() {
  // ✅ ETH → USDC (works)
  await swap({
    poolKey: {
      currency0: ethers.ZeroAddress,
      currency1: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      fee: 3000,
      tickSpacing: 60,
      hooks: ethers.ZeroAddress
    },
    amountIn: "0.01",
    zeroForOne: true
  });

  // ⚠️ USDC → ETH currently not working
  // Error: The contract's SETTLE_ALL/TAKE_ALL encoding needs fixing
  // for ERC20 → ETH swaps (CurrencyNotSettled error 0xd81b2f2e)
  
  // await swap({
  //   poolKey: {
  //     currency0: ethers.ZeroAddress,
  //     currency1: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  //     fee: 3000,
  //     tickSpacing: 60,
  //     hooks: ethers.ZeroAddress
  //   },
  //   amountIn: "10", // 10 USDC
  //   zeroForOne: false
  // });
}

main().catch(console.error);
