import { ethers } from "ethers";

const wallet = ethers.Wallet.createRandom();

console.log("=== New Wallet Generated ===");
console.log("Address:", wallet.address);
console.log("Private Key:", wallet.privateKey);
console.log("");
console.log("Copy the private key into your .env file");
console.log("Copy the address and get testnet ETH from a Base Sepolia faucet");