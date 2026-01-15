#!/usr/bin/env bash
set -e

RPC="http://127.0.0.1:8545"
TARGET=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
WHALE=0xa7C0D36c4698981FAb42a7d8c783674c6Fe2592d

# check initial balances
echo "Initial Balances:"
cast balance $WHALE --rpc-url $RPC
cast balance $TARGET --rpc-url $RPC

# Fund the whale account
# cast rpc anvil_setBalance $WHALE 0x56BC75E2D63100000 --rpc-url $RPC

# Fund the target account directly (100 ETH = 0x56BC75E2D63100000 wei)
cast rpc anvil_setBalance $TARGET 0x56BC75E2D63100000 --rpc-url $RPC

# check the balances
cast balance $WHALE --rpc-url $RPC
cast balance $TARGET --rpc-url $RPC

echo "✅ Accounts funded with 100 ETH each"
