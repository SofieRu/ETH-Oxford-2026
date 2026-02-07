import "dotenv/config";
import { ethers } from "ethers";
import { existsSync } from "node:fs";
import { evaluate } from "./strategy.js";

// --- ROFL TEE Key Generation ---
const ROFL_SOCKET = "/run/rofl-appd.sock";

async function getPrivateKey() {
	// If running inside TEE → generate key from hardware
	if (existsSync(ROFL_SOCKET)) {
		const { RoflClient, KeyKind } = await import("@oasisprotocol/rofl-client");
		const client = new RoflClient();
		const hex = await client.generateKey("trading-bot-key", KeyKind.SECP256K1);
		console.log("🔐 Key generated INSIDE TEE (hardware-derived)");
		return hex.startsWith("0x") ? hex : `0x${hex}`;
	}

	// If running locally → use .env key
	if (process.env.PRIVATE_KEY) {
		console.log("🔑 Using local .env key (NOT secure — dev mode only)");
		return process.env.PRIVATE_KEY;
	}

	throw new Error("No key available. Set PRIVATE_KEY in .env or run inside TEE.");
}

// --- Config ---
const SWAP_AMOUNT = process.env.TRADE_AMOUNT_ETH ?? "0.001";
const SLIPPAGE_BPS = Number(process.env.SLIPPAGE_BPS ?? "200");

// --- Base Sepolia Contract Addresses ---
const UNISWAP_FACTORY = "0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24";
const QUOTER_V2       = "0xC5290058841028F1614F3A6F0F5816cAd0df5E27";
const SWAP_ROUTER_02  = "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4";
const WETH            = "0x4200000000000000000000000000000000000006";
const USDC            = "0x036CbD53842c5426634e7929541eC2318f3dCF7e";
const FEE_TIERS       = [500, 3000, 10000];

// --- ABIs ---
const FACTORY_ABI = [
	"function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool)"
];

const QUOTER_ABI = [
	"function quoteExactInputSingle((address tokenIn,address tokenOut,uint256 amountIn,uint24 fee,uint160 sqrtPriceLimitX96)) external returns (uint256 amountOut)"
];

const ROUTER_ABI = [
	"function exactInputSingle((address tokenIn,address tokenOut,uint24 fee,address recipient,uint256 amountIn,uint256 amountOutMinimum,uint160 sqrtPriceLimitX96)) external payable returns (uint256 amountOut)"
];

// --- Helpers ---
function applySlippage(amount, bps) {
	return (amount * BigInt(10000 - bps)) / BigInt(10000);
}

// --- Find a Uniswap V3 pool ---
async function findPool(factory) {
	for (const fee of FEE_TIERS) {
		const pool = await factory.getPool(WETH, USDC, fee);
		if (pool !== ethers.ZeroAddress) {
			return { pool, fee };
		}
	}
	throw new Error("No Uniswap V3 pool found for WETH/USDC on Base Sepolia.");
}

// --- Get quote + execute swap ---
async function executeSwap(wallet, fee) {
	const quoter = new ethers.Contract(QUOTER_V2, QUOTER_ABI, wallet);
	const router = new ethers.Contract(SWAP_ROUTER_02, ROUTER_ABI, wallet);
	const amountIn = ethers.parseEther(SWAP_AMOUNT);

	const quotedOut = await quoter.quoteExactInputSingle.staticCall({
		tokenIn: WETH,
		tokenOut: USDC,
		amountIn,
		fee,
		sqrtPriceLimitX96: 0
	});

	const minOut = applySlippage(BigInt(quotedOut), SLIPPAGE_BPS);
	console.log(`   Quoted output: ${ethers.formatUnits(quotedOut, 6)} USDC`);
	console.log(`   Min output (with slippage): ${ethers.formatUnits(minOut, 6)} USDC`);

	const tx = await router.exactInputSingle(
		{
			tokenIn: WETH,
			tokenOut: USDC,
			fee,
			recipient: wallet.address,
			amountIn,
			amountOutMinimum: minOut,
			sqrtPriceLimitX96: 0
		},
		{ value: amountIn }
	);

	console.log(`   ✅ Tx sent: ${tx.hash}`);
	const receipt = await tx.wait();
	console.log(`   ✅ Confirmed in block ${receipt.blockNumber}`);
	console.log(`   🔗 https://sepolia.basescan.org/tx/${tx.hash}`);
}

// --- Main ---
async function main() {
	console.log("====================================");
	console.log("  TEE Trading Bot");
	console.log("====================================\n");

	// Get key (TEE or local)
	const privateKey = await getPrivateKey();

	// Setup
	const rpcUrl = process.env.RPC_URL ?? "https://sepolia.base.org";
	const provider = new ethers.JsonRpcProvider(rpcUrl);
	const wallet = new ethers.Wallet(privateKey, provider);
	console.log(`🤖 Wallet: ${wallet.address}`);

	const balance = await provider.getBalance(wallet.address);
	console.log(`💰 Balance: ${ethers.formatEther(balance)} ETH`);

	// Find pool
	const factory = new ethers.Contract(UNISWAP_FACTORY, FACTORY_ABI, provider);
	const { pool, fee } = await findPool(factory);
	console.log(`🏊 Pool found: ${pool} (fee: ${fee})`);

	// Evaluate strategy
	const decision = await evaluate();

	// Act on decision
	if (decision.action === "SWAP") {
		console.log(`\n🔄 Executing swap: ${SWAP_AMOUNT} ETH → USDC\n`);
		await executeSwap(wallet, fee);
	} else {
		console.log(`\n⏸️  Holding. Score too low for swap.`);
	}

	console.log("\n====================================");
	console.log("  Bot run complete.");
	console.log("====================================");
}

main().catch(console.error);
