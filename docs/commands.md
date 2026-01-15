chmod +x impersonate.sh
./impersonate.sh

source .env && forge script script/uniswap.s.sol --rpc-url $FORK_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY

