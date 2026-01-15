# AllInOne DeFi Project

A comprehensive DeFi project featuring token staking with vote-escrowed governance tokens and Uniswap V4 swap integration on Base network.

## 📋 Project Overview

This project contains:

- **MTK Token**: ERC20 token with 1M initial supply
- **veMTK**: Non-transferable vote-escrowed governance token
- **Staking System**: Stake MTK to earn rewards and mint veMTK
- **Uniswap V4 Integration**: Swap contract using Universal Router with V4_SWAP commands

## 🏗️ Architecture

### Core Contracts

#### MTK (MyToken)
- Standard ERC20 token
- Initial supply: 1,000,000 MTK
- Deployed for staking and rewards

#### veMTK (Vote Escrow MTK)
- Non-transferable ERC20 token
- Minted 1:1 when staking MTK
- Burned when unstaking
- Used for governance weight and reward calculations

#### MTKStaking
- 7-day lock period for staked tokens
- 10% APY base rewards
- Weighted rewards based on veMTK share of total supply
- Configurable maximum reward pool
- Instant veMTK minting on stake
- Claim rewards while staked or withdraw with rewards

#### UniswapV4Swapper
- Integrates with Uniswap V4 via Universal Router
- Supports both ETH and ERC20 token swaps
- Uses Permit2 for efficient token approvals
- Implements V4_SWAP command with Actions (SWAP_EXACT_IN_SINGLE, SETTLE_ALL, TAKE_ALL)
- Deployed on Base network

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (v16+)
- [pnpm](https://pnpm.io/) or npm

### Installation

```bash
# Clone the repository
git clone https://github.com/SagarKarmoker/uniswap-v4.git
cd allinone

# Install Solidity dependencies
forge install

# Install TypeScript dependencies
npm install
```

### Environment Setup

Create a `.env` file:

```env
# RPC URLs
BASE_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY
FORK_RPC_URL=http://localhost:8545

# Private Keys
DEPLOYER_PRIVATE_KEY=0x...
```

## 🔧 Development

### Build Contracts

```bash
forge build
```

### Run Tests

```bash
# Run Solidity tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test testStaking
```

### Deploy Contracts

#### Deploy MTK Staking System

```bash
# To local Anvil
forge script script/mtkDeploy.s.sol --rpc-url $FORK_RPC_URL --broadcast

# To Base mainnet
forge script script/mtkDeploy.s.sol --rpc-url base --broadcast --verify
```

#### Deploy Uniswap V4 Swapper

```bash
# To Base fork (requires running Anvil)
forge script script/deploy.s.sol --rpc-url $FORK_RPC_URL --broadcast
```

**Deployed Addresses (Base Mainnet Fork):**
- UniswapV4Swapper: `0xDF9a2f5152c533F7fcc3bAdEd41e157C9563C695`
- PoolManager: `0x498581ff718922c3f8e6a244956af099b2652b2b`
- Universal Router: `0x6ff5693b99212da76ad316178a184ab56d299b43`
- Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- Quoter: `0x0d5e0f971ed27fbff6c2837bf31316121532048d`

## 🌐 Running Local Fork

Start Anvil with Base mainnet fork:

```bash
anvil --fork-url https://base-mainnet.g.alchemy.com/v2/YOUR_KEY
```

## 💱 Uniswap V4 Swap Scripts

### Find Available Pools

Discover working V4 pools on Base:

```bash
npx tsx scripts/uniswapv4/findPools.ts
```

**Known Working Pools on Base:**
- ETH/USDC (0.3% fee, tickSpacing: 60)
- ETH/USDC (0.05% fee, tickSpacing: 10)
- ETH/DAI (0.3% fee, tickSpacing: 60)

### Execute Swaps

Run the minimal, dynamic swap script:

```bash
npx tsx scripts/uniswapv4/swap.ts
```

**Example swap configuration:**

```typescript
await swap({
  poolKey: {
    currency0: ethers.ZeroAddress, // ETH
    currency1: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", // USDC
    fee: 3000, // 0.3%
    tickSpacing: 60,
    hooks: ethers.ZeroAddress
  },
  amountIn: "0.01" // Swap 0.01 ETH
});
```

### Test Account Funding

Fund test accounts with ETH:

```bash
./impersonate.sh
```

Fund test accounts with ERC20 tokens (e.g., USDC):

```bash
./docs/erc20_impersonate.sh
```

**Test Accounts:**
- Deployer: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Test Account: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
- USDC Whale: `0x8da91A6298eA5d1A8Bc985e99798fd0A0f05701a`

## 📝 Contract Interactions

### MTK Staking

#### Stake MTK

```solidity
// Approve MTK for staking contract
mtk.approve(stakingAddress, amount);

// Stake tokens (receives veMTK instantly)
staking.stake(1000 * 10**18);
```

#### Claim Rewards

```solidity
// Claim rewards while keeping stake active
staking.claimReward();
```

#### Withdraw

```solidity
// Withdraw staked tokens + rewards after lock period
staking.withdraw();
```

### Uniswap V4 Swaps

#### Swap ETH for USDC

```typescript
const swapper = new ethers.Contract(SWAPPER_ADDRESS, SWAPPER_ABI, signer);

await swapper.swapExactInputSingle(
  {
    currency0: ethers.ZeroAddress,
    currency1: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    fee: 3000,
    tickSpacing: 60,
    hooks: ethers.ZeroAddress
  },
  true, // zeroForOne
  ethers.parseEther("0.01"), // amountIn
  0, // amountOutMinimum
  Math.floor(Date.now() / 1000) + 600, // deadline
  { value: ethers.parseEther("0.01") }
);
```

## 🧪 Testing

### Staking Tests

Located in `test/Staking.t.sol`:
- Basic staking functionality
- Reward calculations
- Lock period enforcement
- veMTK minting/burning

### Swap Tests

Located in `test/SwapOnV4.t.sol`:
- V4 pool integration
- Token swap execution
- ETH/ERC20 handling

## 🔍 Key Features

### Staking System

✅ **7-day lock period** - Prevents premature withdrawals  
✅ **10% APY** - Base reward rate for stakers  
✅ **veMTK governance** - Vote-escrowed tokens for governance  
✅ **Weighted rewards** - Rewards adjusted by veMTK share  
✅ **Reward cap** - Maximum reward pool protection  
✅ **Instant veMTK** - Governance tokens minted on stake  
✅ **Non-transferable veMTK** - Prevents vote trading  

### Uniswap V4 Integration

✅ **Universal Router** - Latest V4_SWAP command support  
✅ **ETH & ERC20** - Supports both native and token swaps  
✅ **Permit2** - Gas-efficient token approvals  
✅ **Actions** - SWAP_EXACT_IN_SINGLE, SETTLE_ALL, TAKE_ALL  
✅ **Base Network** - Deployed on Layer 2 for low fees  
✅ **Dynamic pools** - Easy configuration for different pools  

## 📊 Reward Calculation

Rewards are calculated using:

```
baseReward = (stakedAmount * 10% * duration) / (365 days)
weightedReward = (baseReward * userVeMTK) / totalVeMTK
```

With caps:
- Maximum reward pool configured at deployment
- Rewards proportional to user's veMTK share
- No rewards if total veMTK supply is 0

## 🛠️ Technology Stack

- **Solidity** ^0.8.26
- **Foundry** - Development framework
- **OpenZeppelin** - Security libraries
- **Uniswap V4** - DEX protocol
- **TypeScript** - Script automation
- **Ethers.js** v6 - Ethereum interactions
- **Base Network** - Layer 2 deployment

## 📚 Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Uniswap V4 Docs](https://docs.uniswap.org/contracts/v4/overview)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Base Network](https://docs.base.org/)

## 🔐 Security Considerations

- ✅ ReentrancyGuard on all state-changing functions
- ✅ SafeERC20 for token transfers
- ✅ Non-transferable veMTK prevents vote manipulation
- ✅ Deadline protection on swaps
- ⚠️ Contracts not audited - use at your own risk
- ⚠️ Test thoroughly on testnets before mainnet

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

## 📄 License

MIT

## 🐛 Known Issues

- Universal Router must be on `main` branch for V4_SWAP support (v1.6.0 doesn't include it)
- Pool must exist on-chain before swapping (use findPools.ts to verify)
- Anvil fork required for local testing with mainnet pools

## 💬 Support

For issues and questions:
1. Check existing documentation
2. Review test files for examples
3. Open an issue on GitHub

---

Built with ❤️ using Foundry & Uniswap V4
