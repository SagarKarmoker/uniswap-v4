import { ethers } from "ethers";

const RPC = "http://localhost:8545";
const provider = new ethers.JsonRpcProvider(RPC);

async function test() {
    const blockNumber = await provider.getBlockNumber();
    console.log("Current block number:", blockNumber);
}

async function walletBalance() {
    const address = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
    const balance = await provider.getBalance(address);
    console.log(`Balance of ${address}:`, ethers.formatEther(balance), "ETH");
}

async function erc20check() {
    const erc20Abi = [
        "function name() view returns (string)",
        "function symbol() view returns (string)",
        "function totalSupply() view returns (uint256)",
        "function balanceOf(address) view returns (uint256)",
    ];
    
    const tokenAddress = "0x7a54A933E6A02051127C5dec7eB399C81c3c53a7";

    const tokenContract = new ethers.Contract(tokenAddress, erc20Abi, provider);
    
    const name = await tokenContract.name();
    const symbol = await tokenContract.symbol();
    const totalSupply = await tokenContract.totalSupply();
    const balance = await tokenContract.balanceOf("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
    console.log(`Token Name: ${name}`);
    console.log(`Token Symbol: ${symbol}`);
    console.log(`Total Supply: ${ethers.formatUnits(totalSupply, 18)} ${symbol}`);
    console.log(`Balance: ${ethers.formatUnits(balance, 18)} ${symbol}`);
}

async function transferToken() {
    const erc20Abi = [
        "function transfer(address to, uint amount) returns (bool)",
        "function balanceOf(address) view returns (uint256)",
    ];

    const tokenAddress = "0x7a54A933E6A02051127C5dec7eB399C81c3c53a7";
    const privateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
    const wallet = new ethers.Wallet(privateKey, provider);
    const tokenContract = new ethers.Contract(tokenAddress, erc20Abi, wallet);
    
    const toAddress = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
    const amount = ethers.parseUnits("10.0", 18);
    
    const tx = await tokenContract.transfer(toAddress, amount);
    console.log("Transfer transaction hash:", tx.hash);
    await tx.wait();
    console.log("Transfer completed.");
}

// walletBalance().catch((error) => {
//     console.error("Error in walletBalance function:", error);
//     process.exit(1);
// });

// erc20check().catch((error) => {
//     console.error("Error in erc20check function:", error);
//     process.exit(1);
// });

transferToken().catch((error) => {
    console.error("Error in transferToken function:", error);
    process.exit(1);
});