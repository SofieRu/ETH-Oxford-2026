import "dotenv/config";
import { loadPolicy, checkPolicy, recordTrade, getTradingState } from "./policy";
import type { TradingSignal } from "./strategy";

function makeSignal(action: "BUY" | "SELL" | "HOLD", amount: number, price: number = 3500): TradingSignal {
  return {
    action,
    amount,
    price,
    rsi: 50,
    reason: "test",
    timestamp: Math.floor(Date.now() / 1000),
  };
}

async function main(): Promise<void> {
  console.log("=== Policy test ===\n");

  const policy = loadPolicy();
  console.log("Policy limits (from .env):");
  console.log("  maxTradeSize      :", policy.maxTradeSize, "ETH");
  console.log("  dailyLimit        :", policy.dailyLimit, "ETH");
  console.log("  minTradeInterval  :", policy.minTradeInterval, "s");
  console.log("  maxSlippage       :", (policy.maxSlippage * 100).toFixed(1), "%");
  console.log("  allowedTokens     :", policy.allowedTokens.length, "tokens");
  console.log("  emergencyStop     :", policy.emergencyStop);
  console.log();

  let result: { allowed: boolean; reason?: string };
  let signal: TradingSignal;
  const outcome = (pass: boolean, msg: string) => (pass ? "✅ PASS" : "❌ FAIL") + " — " + msg;

  // --- Test 1: Valid trade — expect ALLOWED ---
  console.log("--- Test 1: Allow valid trade (0.3 ETH BUY, within limits) ---");
  signal = makeSignal("BUY", 0.3);
  result = checkPolicy(signal, policy);
  if (result.allowed) {
    console.log(outcome(true, "Trade allowed and recorded"));
    recordTrade(signal);
  } else {
    console.log(outcome(false, "Expected allowed, was rejected: " + (result.reason ?? "")));
  }
  console.log();

  // --- Test 2: Trade too large — expect REJECTED ---
  console.log("--- Test 2: Reject trade over max size (1.0 ETH > 0.5 ETH max) ---");
  signal = makeSignal("BUY", 1.0);
  result = checkPolicy(signal, policy);
  if (!result.allowed) {
    console.log(outcome(true, "Correctly rejected: " + (result.reason ?? "")));
  } else {
    console.log(outcome(false, "Expected rejected (exceeds max trade size), was allowed"));
  }
  console.log();

  // --- Test 3a: Second trade rejected due to rate limit — expect REJECTED ---
  console.log("--- Test 3a: Reject second trade due to rate limit (0s < 600s min interval) ---");
  signal = makeSignal("BUY", 0.3);
  result = checkPolicy(signal, policy);
  if (!result.allowed && result.reason && result.reason.toLowerCase().includes("interval")) {
    console.log(outcome(true, "Correctly rejected: " + (result.reason ?? "")));
  } else if (result.allowed) {
    console.log(outcome(false, "Expected rejected (min interval), was allowed"));
  } else {
    console.log(outcome(false, "Expected rejected with reason containing 'interval': " + (result.reason ?? "")));
  }
  console.log();

  // --- Test 3b: Would exceed daily limit — expect REJECTED ---
  console.log("--- Test 3b: Reject trade that would exceed daily limit (2.0 ETH → 2.6 > 2.0) ---");
  signal = makeSignal("BUY", 2.0);
  result = checkPolicy(signal, policy);
  if (!result.allowed) {
    console.log(outcome(true, "Correctly rejected: " + (result.reason ?? "")));
  } else {
    console.log(outcome(false, "Expected rejected (exceeds daily limit), was allowed"));
  }
  console.log();

  // --- Test 4: Too soon after last trade — expect REJECTED ---
  console.log("--- Test 4: Reject trade when min interval not met (too soon after previous) ---");
  signal = makeSignal("BUY", 0.2);
  result = checkPolicy(signal, policy);
  if (!result.allowed) {
    console.log(outcome(true, "Correctly rejected: " + (result.reason ?? "")));
  } else {
    console.log(outcome(false, "Expected rejected (min interval), was allowed"));
  }
  console.log();

  // --- Test 5: HOLD — expect ALLOWED (no trade to execute) ---
  console.log("--- Test 5: Allow HOLD signal (no trade needed, skip execution) ---");
  signal = makeSignal("HOLD", 0);
  result = checkPolicy(signal, policy);
  if (result.allowed) {
    console.log(outcome(true, (result.reason ?? "HOLD handled, no trade needed")));
  } else {
    console.log(outcome(false, "Expected allowed for HOLD, was rejected: " + (result.reason ?? "")));
  }
  console.log();

  // --- Final state ---
  const state = getTradingState();
  console.log("--- Final trading state ---");
  console.log("  dailyVolume  :", state.dailyVolume, "ETH");
  console.log("  lastTradeTime:", state.lastTradeTime, state.lastTradeTime > 0 ? "(epoch s)" : "");
  console.log("  usedNonces   :", state.usedNonces.size, "entries");
  console.log("  startOfDay   :", state.startOfDay);
  console.log("\n✅ Policy test complete.");
}

main().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});
