#!/usr/bin/env bash
set -e

RPC="http://127.0.0.1:8545"
USDC_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
WHALE=0x8da91A6298eA5d1A8Bc985e99798fd0A0f05701a
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
