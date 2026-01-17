#!/usr/bin/env bash
set -e

RPC="http://127.0.0.1:8545"
USDC_TOKEN=0xFCa95aeb5bF44aE355806A5ad14659c940dC6BF7
WHALE=0xd828E39eA39fe2a648Cf5872c528c4e0B4f3CcB2
TARGET=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
AMOUNT=10000000000000 # 10M USDC (6 decimals)

echo "📊 Initial USDC Balances:"
echo "Whale:"
cast call $USDC_TOKEN "balanceOf(address)(uint256)" $WHALE --rpc-url $RPC
echo "Target:"
cast call $USDC_TOKEN "balanceOf(address)(uint256)" $TARGET --rpc-url $RPC

echo ""
echo "🔓 Impersonating whale and transferring USDC..."

# Fund the whale with ETH for gas
cast rpc anvil_setBalance $WHALE 0x56BC75E2D63100000 --rpc-url $RPC

# Impersonate the whale and transfer USDC
cast rpc anvil_impersonateAccount $WHALE --rpc-url $RPC
cast send $USDC_TOKEN "transfer(address,uint256)(bool)" $TARGET $AMOUNT --from $WHALE --unlocked --rpc-url $RPC
cast rpc anvil_stopImpersonatingAccount $WHALE --rpc-url $RPC

echo ""
echo "📊 Final USDC Balances:"
echo "Whale:"
cast call $USDC_TOKEN "balanceOf(address)(uint256)" $WHALE --rpc-url $RPC
echo "Target:"
cast call $USDC_TOKEN "balanceOf(address)(uint256)" $TARGET --rpc-url $RPC

echo ""
echo "✅ Successfully transferred 10M USDC to target"
