import "dotenv/config";
import { ethers } from "ethers";
import { initWallet, getBalance } from "./wallet";
import { generateSignal, type TradingSignal } from "./strategy";
import { loadPolicy, checkPolicy, recordTrade, type PolicyConfig } from "./policy";
import { executeSwap } from "./trader";

const DEFAULT_TRADE_CHECK_INTERVAL_MS = 10 * 60 * 1000; // 10 minutes
const API_RETRY_DELAY_MS = 60 * 1000; // 1 minute on API failure

function getTradeCheckIntervalMs(): number {
  const v = process.env.TRADE_CHECK_INTERVAL_MS;
  if (v === undefined) return DEFAULT_TRADE_CHECK_INTERVAL_MS;
  const n = parseInt(v, 10);
  return Number.isNaN(n) || n < 1000 ? DEFAULT_TRADE_CHECK_INTERVAL_MS : n;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function runLoop(
  wallet: Awaited<ReturnType<typeof initWallet>>,
  provider: ethers.JsonRpcProvider,
  policy: PolicyConfig
): Promise<void> {
  const intervalMs = getTradeCheckIntervalMs();
  console.log("[main] Agent loop started. Check interval:", intervalMs / 1000, "s");
  console.log("[main] Emergency stop:", policy.emergencyStop ? "ON (no trades)" : "OFF");
  console.log();

  for (;;) {
    const cycleStart = Date.now();

    if (policy.emergencyStop) {
      console.log("[main] Emergency stop active — skipping cycle. Set EMERGENCY_STOP=0 to resume.");
      await sleep(intervalMs);
      continue;
    }

    let signal: TradingSignal;
    try {
      console.log("[main] Generating trading signal...");
      signal = await generateSignal();
      console.log("[main] Signal:", signal.action, "| amount:", signal.amount, "ETH | price:", signal.price, "| RSI:", signal.rsi, "|", signal.reason);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error("[main] API/strategy error:", msg);
      console.log("[main] Waiting", API_RETRY_DELAY_MS / 1000, "s before retry...");
      await sleep(API_RETRY_DELAY_MS);
      continue;
    }

    const check = checkPolicy(signal, policy);
    if (!check.allowed) {
      console.log("[main] Policy rejected:", check.reason ?? "unknown");
      await sleep(intervalMs);
      continue;
    }

    if (signal.action === "HOLD") {
      console.log("[main] No trade (HOLD). Next check in", intervalMs / 1000, "s");
      await sleep(intervalMs);
      continue;
    }

    console.log("[main] Executing swap:", signal.action, signal.amount, "ETH...");
    const result = await executeSwap(signal, wallet, provider);
    if (result.success) {
      console.log("[main] Trade executed. Tx hash:", result.txHash);
      recordTrade(signal);
    } else {
      console.error("[main] Trade failed:", result.error);
    }

    const elapsed = Date.now() - cycleStart;
    const waitMs = Math.max(0, intervalMs - elapsed);
    console.log("[main] Next check in", Math.round(waitMs / 1000), "s");
    await sleep(waitMs);
  }
}

async function main(): Promise<void> {
  console.log("=== Sovereign AI TEE agent ===\n");

  const rpcUrl = process.env.RPC_URL;
  if (!rpcUrl) {
    console.error("RPC_URL is not set in .env");
    process.exit(1);
  }
  console.log("[main] RPC:", rpcUrl);
  console.log("[main] CHAIN_ID:", process.env.CHAIN_ID ?? "(from RPC)");

  console.log("[main] Initializing wallet...");
  const wallet = await initWallet();
  console.log("[main] Wallet:", wallet.address);

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  try {
    const balance = await getBalance(wallet, provider);
    console.log("[main] Balance:", ethers.formatEther(balance), "ETH");
  } catch (e) {
    console.warn("[main] Could not fetch balance (RPC may be slow):", e instanceof Error ? e.message : String(e));
  }

  console.log("[main] Loading policy...");
  const policy = loadPolicy();
  console.log("[main] Policy: maxTradeSize =", policy.maxTradeSize, "ETH, dailyLimit =", policy.dailyLimit, "ETH");
  console.log();

  await runLoop(wallet, provider, policy);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
