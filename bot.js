import "dotenv/config";
import { ethers } from "ethers";

// Base Sepolia + Uniswap v3 addresses
const UNISWAP_FACTORY = "0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24";
const QUOTER_V2      = "0xC5290058841028F1614F3A6F0F5816cAd0df5E27";
const SWAP_ROUTER_02 = "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4";
const WETH           = "0x4200000000000000000000000000000000000006";
const USDC           = "0x036CbD53842c5426634e7929541eC2318f3dCF7e";
const FEE_TIERS      = [500, 3000, 10000];

const FACTORY_ABI = [
	"function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool)"
];

const QUOTER_ABI = [
	"function quoteExactInputSingle((address tokenIn,address tokenOut,uint256 amountIn,uint24 fee,uint160 sqrtPriceLimitX96)) external returns (uint256 amountOut)"
];

function mustEnv(name) {
	const v = process.env[name];
	if (!v) throw new Error(`Missing env var: ${name}`);
	return v;
}

function applySlippage(amount, bps) {
	return (amount * BigInt(10000 - bps)) / BigInt(10000);
}

async function main() {
	const provider = new ethers.JsonRpcProvider(mustEnv("RPC_URL"));
	const wallet = new ethers.Wallet(mustEnv("PRIVATE_KEY"), provider);

	console.log("Wallet:", wallet.address);

	const factory = new ethers.Contract(UNISWAP_FACTORY, FACTORY_ABI, provider);
	const quoter  = new ethers.Contract(QUOTER_V2, QUOTER_ABI, wallet);

	const amountIn = ethers.parseEther(process.env.TRADE_AMOUNT_ETH ?? "0.001");
	const slippageBps = Number(process.env.SLIPPAGE_BPS ?? "200");

	let feeFound = null;
	let poolFound = null;

	for (const fee of FEE_TIERS) {
		const pool = await factory.getPool(WETH, USDC, fee);
		if (pool !== ethers.ZeroAddress) {
			feeFound = fee;
			poolFound = pool;
			break;
		}
	}

	if (!poolFound) throw new Error("No Uniswap v3 pool found for WETH/USDC on Base Sepolia.");

	console.log("Pool:", poolFound);
	console.log("Fee:", feeFound);

	const quotedOut = await quoter.quoteExactInputSingle.staticCall({
		tokenIn: WETH,
		tokenOut: USDC,
		amountIn,
		fee: feeFound,
		sqrtPriceLimitX96: 0
	});

	const minOut = applySlippage(BigInt(quotedOut), slippageBps);

	console.log("Quoted USDC out:", quotedOut.toString());
	console.log("Min USDC out:", minOut.toString());
	console.log("Dry run only. Next we’ll add the swap tx + --trade-now trigger.");
}

main().catch(e => {
	console.error("ERROR:", e.message);
	process.exit(1);
});