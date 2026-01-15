import { ethers, NonceManager } from "ethers";

const RPC = "http://localhost:8545";
const provider = new ethers.JsonRpcProvider(RPC);

/**
 * == Deployment Summary ==
 * MTK:        0x8acE90A7bb0B933ba6d9f6989dc5e974d03B56Fe
 * veMTK:      0xa2cDfbad2E8bf8eBff3bb7df6Aff8aaad1D5ca45
 * MTKStaking: 0x7d227414707e9d286213AB1AeC8703507C172605
 */

const MTK_ADDRESS = "0x8acE90A7bb0B933ba6d9f6989dc5e974d03B56Fe";
const VEMTK_ADDRESS = "0xa2cDfbad2E8bf8eBff3bb7df6Aff8aaad1D5ca45";
const STAKING_ADDRESS = "0x7d227414707e9d286213AB1AeC8703507C172605";

const DEPLOYER_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const ALICE_PRIVATE_KEY =
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";

const MTK_ABI = [
  "function transfer(address to, uint256 amount) returns (bool)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function balanceOf(address) view returns (uint256)",
];

const VEMTK_ABI = [
  "function balanceOf(address) view returns (uint256)",
];

const STAKING_ABI = [
  "function stake(uint256 amount)",
  "function withdraw()",
  "function timeLeft(address user) view returns (uint256)",
];

async function main() {
  console.log("🚀 Starting MTK Staking Interaction Test\n");

  // ✅ NONCE-SAFE SIGNERS
  const deployer = new NonceManager(
    new ethers.Wallet(DEPLOYER_PRIVATE_KEY, provider)
  );

  const alice = new NonceManager(
    new ethers.Wallet(ALICE_PRIVATE_KEY, provider)
  );

  console.log("Deployer:", await deployer.getAddress());
  console.log("Alice:   ", await alice.getAddress(), "\n");

  const mtk = new ethers.Contract(MTK_ADDRESS, MTK_ABI, provider);
  const vemtk = new ethers.Contract(VEMTK_ADDRESS, VEMTK_ABI, provider);
  const staking = new ethers.Contract(STAKING_ADDRESS, STAKING_ABI, provider);

  /* ---------------------------------------------------------- */
  /* 1. Deployer → Alice : 1000 MTK                              */
  /* ---------------------------------------------------------- */
  console.log("1️⃣ Transfer 1000 MTK → Alice");
  await (await mtk.connect(deployer).transfer(
    await alice.getAddress(),
    ethers.parseEther("1000")
  )).wait();

  console.log(
    "   Alice MTK balance:",
    ethers.formatEther(await mtk.balanceOf(await alice.getAddress())),
    "MTK\n"
  );

  /* ---------------------------------------------------------- */
  /* 2. Alice approves staking contract                          */
  /* ---------------------------------------------------------- */
  console.log("2️⃣ Alice approves staking contract");
  await (await mtk.connect(alice).approve(
    STAKING_ADDRESS,
    ethers.parseEther("1000")
  )).wait();
  console.log("   ✓ Approved\n");

  /* ---------------------------------------------------------- */
  /* 3. Alice stakes 1000 MTK                                    */
  /* ---------------------------------------------------------- */
  console.log("3️⃣ Alice stakes 1000 MTK");
  await (await staking.connect(alice).stake(
    ethers.parseEther("1000")
  )).wait();
  console.log("   ✓ Staked\n");

  /* ---------------------------------------------------------- */
  /* 4. veMTK balance check                                     */
  /* ---------------------------------------------------------- */
  console.log("4️⃣ Checking veMTK balance");
  const veBal = await vemtk.balanceOf(await alice.getAddress());
  console.log("   veMTK:", ethers.formatEther(veBal), "veMTK\n");

  /* ---------------------------------------------------------- */
  /* 5. Early withdrawal (should fail)                          */
  /* ---------------------------------------------------------- */
  console.log("5️⃣ Attempt early withdrawal (expect revert)");
  try {
    await (await staking.connect(alice).withdraw()).wait();
    console.log("❌ Withdrawal succeeded (BUG)\n");
  } catch {
    console.log("✅ Withdrawal reverted as expected\n");
  }

  const timeLeft = await staking.timeLeft(await alice.getAddress());
  console.log(
    `⏱️  Time left: ${timeLeft} seconds (~${Math.ceil(
      Number(timeLeft) / 86400
    )} days)`
  );

  console.log("\n🎉 Script completed successfully");
}

main().catch(console.error);
