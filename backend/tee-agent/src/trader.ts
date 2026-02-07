import { ethers, type TransactionRequest, type Provider } from "ethers";
import type { TradingSignal } from "./strategy";
import type { WalletHandle } from "./wallet";

const UNISWAP_V2_ROUTER = "0x4752ba5dbc23f44d87826276bf6b1c372ad24";

const ROUTER_ABI = [
  "function swapExactETHForTokens(uint256 amountOutMin, address[] path, address to, uint256 deadline) external payable returns (uint256[] amounts)",
  "function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline) external returns (uint256[] amounts)",
];

const DEADLINE_SECONDS = 300;
const USDC_DECIMALS = 6;

function getWethAddress(): string {
  const a = process.env.WETH_ADDRESS;
  if (!a) throw new Error("WETH_ADDRESS not set in .env");
  return a;
}

function getUsdcAddress(): string {
  const a = process.env.USDC_ADDRESS;
  if (!a) throw new Error("USDC_ADDRESS not set in .env");
  return a;
}

function getMaxSlippageDecimal(): number {
  const p = process.env.MAX_SLIPPAGE_PERCENT;
  const n = p ? parseFloat(p) : 2;
  return (Number.isNaN(n) ? 2 : n) / 100;
}

/**
 * Returns minimum acceptable output for a given input and slippage (e.g. 0.02 = 2%).
 */
export function estimateAmountOut(amountIn: number, slippageDecimal: number): number {
  return amountIn * (1 - slippageDecimal);
}

/**
 * Builds a Uniswap V2 swap transaction (BUY: ETH→USDC, SELL: USDC→ETH).
 * Uses env: WETH_ADDRESS, USDC_ADDRESS, MAX_SLIPPAGE_PERCENT.
 */
export async function buildSwapTransaction(
  signal: TradingSignal,
  wallet: WalletHandle,
  provider: Provider
): Promise<TransactionRequest> {
  const weth = getWethAddress();
  const usdc = getUsdcAddress();
  const slippage = getMaxSlippageDecimal();
  const to = wallet.address;
  const deadline = Math.floor(Date.now() / 1000) + DEADLINE_SECONDS;

  const iface = new ethers.Interface(ROUTER_ABI as string[]);
  const amountEth = signal.amount;
  const price = signal.price;

  let data: string;
  let value: bigint | undefined;

  if (signal.action === "BUY") {
    console.log("[trader] Building BUY transaction: swapExactETHForTokens (ETH → USDC)");
    const valueWei = ethers.parseEther(amountEth.toString());
    const estimatedUsdc = amountEth * price;
    const amountOutMinUsdc = estimateAmountOut(estimatedUsdc, slippage);
    const amountOutMin = BigInt(Math.floor(amountOutMinUsdc * 10 ** USDC_DECIMALS));
    const path = [weth, usdc];
    data = iface.encodeFunctionData("swapExactETHForTokens", [amountOutMin, path, to, BigInt(deadline)]);
    value = valueWei;
    console.log("[trader] Path: [WETH, USDC], value:", ethers.formatEther(valueWei), "ETH, amountOutMin (USDC 6d):", amountOutMin.toString());
  } else if (signal.action === "SELL") {
    console.log("[trader] Building SELL transaction: swapExactTokensForETH (USDC → ETH)");
    const amountUsdc = amountEth * price;
    const amountInUsdc = BigInt(Math.floor(amountUsdc * 10 ** USDC_DECIMALS));
    const minEthOut = estimateAmountOut(amountEth, slippage);
    const amountOutMinWei = ethers.parseEther(minEthOut.toString());
    const path = [usdc, weth];
    data = iface.encodeFunctionData("swapExactTokensForETH", [amountInUsdc, amountOutMinWei, path, to, BigInt(deadline)]);
    value = undefined;
    console.log("[trader] Path: [USDC, WETH], amountIn (USDC 6d):", amountInUsdc.toString(), ", amountOutMin (wei):", amountOutMinWei.toString());
  } else {
    throw new Error("buildSwapTransaction: signal.action must be BUY or SELL, got " + signal.action);
  }

  let feeData: Awaited<ReturnType<Provider["getFeeData"]>> | null = null;
  try {
    feeData = await provider.getFeeData();
  } catch (e) {
    console.log("[trader] RPC getFeeData failed (network may be unreachable), using fallback gas price");
  }
  const FALLBACK_GAS_PRICE_WEI = 20n * 10n ** 9n; // 20 gwei for Sepolia/testnets
  const tx: TransactionRequest = {
    to: UNISWAP_V2_ROUTER,
    data,
    value: value ?? 0n,
    gasLimit: 300000n,
  };
  if (feeData?.gasPrice != null && feeData.gasPrice > 0n) {
    tx.gasPrice = feeData.gasPrice;
  } else if (feeData?.maxFeePerGas != null) {
    tx.maxFeePerGas = feeData.maxFeePerGas;
    tx.maxPriorityFeePerGas = feeData.maxPriorityFeePerGas ?? feeData.maxFeePerGas / 2n;
  } else {
    tx.gasPrice = FALLBACK_GAS_PRICE_WEI;
    console.log("[trader] Using fallback gasPrice:", FALLBACK_GAS_PRICE_WEI.toString(), "wei");
  }
  console.log("[trader] Gas:", tx.gasPrice ? "gasPrice=" + tx.gasPrice.toString() : "maxFeePerGas=" + tx.maxFeePerGas?.toString());

  console.log("[trader] Transaction: to =", tx.to, ", value =", tx.value?.toString() ?? "0", ", data length =", typeof tx.data === "string" ? tx.data.length : 0, ", gasLimit =", tx.gasLimit?.toString());
  return tx;
}

/**
 * Signs and broadcasts the swap transaction, waits for 1 confirmation.
 */
export async function executeSwap(
  signal: TradingSignal,
  wallet: WalletHandle,
  provider: Provider
): Promise<{ success: true; txHash: string } | { success: false; error: string }> {
  if (signal.action === "HOLD") {
    return { success: false, error: "Cannot execute swap for HOLD signal" };
  }

  try {
    console.log("[trader] Building swap transaction for", signal.action, signal.amount, "ETH...");
    const tx = await buildSwapTransaction(signal, wallet, provider);

    console.log("[trader] Signing transaction...");
    const signedHex = await wallet.signTransaction(tx);

    console.log("[trader] Broadcasting transaction...");
    const submitted = await provider.broadcastTransaction(signedHex);
    const txHash = submitted.hash;
    console.log("[trader] Tx hash:", txHash);

    console.log("[trader] Waiting for 1 confirmation...");
    const receipt = await submitted.wait(1);
    console.log("[trader] Confirmation: block", receipt?.blockNumber ?? "?", "status =", receipt?.status === 1 ? "success" : "reverted");

    return { success: true, txHash };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.log("[trader] Error:", message);
    return { success: false, error: message };
  }
}
