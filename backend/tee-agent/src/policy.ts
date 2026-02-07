import type { TradingSignal } from "./strategy";

/** Trading safety rules loaded from environment. */
export interface PolicyConfig {
  maxTradeSize: number;
  dailyLimit: number;
  allowedTokens: string[];
  maxSlippage: number;
  minTradeInterval: number;
  emergencyStop: boolean;
}

/** Result of a policy check (allowed or rejected with reason). */
export interface PolicyCheckResult {
  allowed: boolean;
  reason?: string;
  details?: unknown;
}

/** Tracks usage for daily limit and min interval enforcement. */
export interface TradingState {
  dailyVolume: number;
  lastTradeTime: number;
  usedNonces: Set<string>;
  startOfDay: number;
}

/** Module-level trading state (in-memory). */
let tradingState: TradingState = {
  dailyVolume: 0,
  lastTradeTime: 0,
  usedNonces: new Set<string>(),
  startOfDay: 0,
};

function startOfDaySeconds(tsSeconds: number): number {
  const d = new Date(tsSeconds * 1000);
  d.setUTCHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
}

/**
 * Loads policy configuration from environment variables.
 * Uses: MAX_TRADE_SIZE_ETH, DAILY_LIMIT_ETH, MIN_TRADE_INTERVAL_SECONDS,
 * MAX_SLIPPAGE_PERCENT, WETH_ADDRESS, USDC_ADDRESS. Optional: EMERGENCY_STOP.
 */
export function loadPolicy(): PolicyConfig {
  const maxTradeSize = parseFloat(process.env.MAX_TRADE_SIZE_ETH ?? "0.5") || 0.5;
  const dailyLimit = parseFloat(process.env.DAILY_LIMIT_ETH ?? "2.0") || 2.0;
  const minTradeInterval = parseInt(process.env.MIN_TRADE_INTERVAL_SECONDS ?? "600", 10) || 600;
  const maxSlippagePercent = parseFloat(process.env.MAX_SLIPPAGE_PERCENT ?? "2.0") || 2.0;
  const maxSlippage = maxSlippagePercent / 100;
  const weth = process.env.WETH_ADDRESS ?? "";
  const usdc = process.env.USDC_ADDRESS ?? "";
  const allowedTokens = [weth, usdc].filter(Boolean);
  const emergencyStop = process.env.EMERGENCY_STOP === "1" || process.env.EMERGENCY_STOP === "true";
  return {
    maxTradeSize,
    dailyLimit,
    allowedTokens,
    maxSlippage,
    minTradeInterval,
    emergencyStop,
  };
}

/**
 * Returns current trading state. Resets daily volume if we're in a new day.
 */
export function getTradingState(): TradingState {
  const now = Math.floor(Date.now() / 1000);
  const startOfToday = startOfDaySeconds(now);
  if (tradingState.startOfDay > 0 && tradingState.startOfDay < startOfToday) {
    console.log("[policy] New day detected — resetting daily volume (was", tradingState.dailyVolume, "ETH)");
    tradingState = {
      ...tradingState,
      dailyVolume: 0,
      startOfDay: startOfToday,
    };
  } else if (tradingState.startOfDay === 0) {
    tradingState = { ...tradingState, startOfDay: startOfToday };
  }
  return tradingState;
}

/**
 * Checks if a trade signal is allowed by policy. Logs each check (✓ pass / ✗ fail).
 */
export function checkPolicy(signal: TradingSignal, policy: PolicyConfig): PolicyCheckResult {
  console.log("[policy] Checking policy for signal:", signal.action, "amount:", signal.amount, "ETH");

  if (policy.emergencyStop) {
    console.log("[policy] ✗ Emergency stop is active");
    return { allowed: false, reason: "Emergency stop active", details: { emergencyStop: true } };
  }
  console.log("[policy] ✓ Emergency stop: not active");

  if (signal.action === "HOLD") {
    console.log("[policy] ✓ HOLD — no trade needed, skip policy");
    return { allowed: true, reason: "HOLD - no trade needed" };
  }

  if (signal.amount > policy.maxTradeSize) {
    console.log("[policy] ✗ Amount", signal.amount, "ETH exceeds max trade size", policy.maxTradeSize, "ETH");
    return {
      allowed: false,
      reason: `Amount ${signal.amount} ETH exceeds max trade size ${policy.maxTradeSize} ETH`,
      details: { amount: signal.amount, maxTradeSize: policy.maxTradeSize },
    };
  }
  console.log("[policy] ✓ Amount within max trade size (", signal.amount, "<=", policy.maxTradeSize, "ETH)");

  const state = getTradingState();
  const dailyAfter = state.dailyVolume + signal.amount;
  if (dailyAfter > policy.dailyLimit) {
    console.log(
      "[policy] ✗ Daily limit would be exceeded:",
      state.dailyVolume,
      "+",
      signal.amount,
      "=",
      dailyAfter,
      ">",
      policy.dailyLimit,
      "ETH"
    );
    return {
      allowed: false,
      reason: `Daily limit would be exceeded (${dailyAfter} > ${policy.dailyLimit} ETH)`,
      details: { dailyVolume: state.dailyVolume, amount: signal.amount, dailyLimit: policy.dailyLimit },
    };
  }
  console.log("[policy] ✓ Daily limit OK (", dailyAfter, "<=", policy.dailyLimit, "ETH)");

  const now = Math.floor(Date.now() / 1000);
  const elapsed = state.lastTradeTime > 0 ? now - state.lastTradeTime : policy.minTradeInterval;
  if (state.lastTradeTime > 0 && elapsed < policy.minTradeInterval) {
    const waitMore = policy.minTradeInterval - elapsed;
    console.log(
      "[policy] ✗ Min trade interval not met:",
      elapsed,
      "s since last trade, need",
      policy.minTradeInterval,
      "s (wait",
      waitMore,
      "s more)"
    );
    return {
      allowed: false,
      reason: `Min trade interval not met (${elapsed}s < ${policy.minTradeInterval}s)`,
      details: { lastTradeTime: state.lastTradeTime, minTradeInterval: policy.minTradeInterval, waitSeconds: waitMore },
    };
  }
  console.log("[policy] ✓ Min trade interval OK (", elapsed, ">=", policy.minTradeInterval, "s)");

  console.log("[policy] ✓ All policy checks passed");
  return { allowed: true };
}

/**
 * Records a completed trade: updates daily volume and last trade time.
 */
export function recordTrade(signal: TradingSignal): void {
  const state = getTradingState();
  const now = Math.floor(Date.now() / 1000);
  tradingState = {
    ...tradingState,
    dailyVolume: state.dailyVolume + signal.amount,
    lastTradeTime: now,
  };
  console.log(
    "[policy] Recorded trade:",
    signal.action,
    signal.amount,
    "ETH @",
    signal.price,
    "| dailyVolume now:",
    tradingState.dailyVolume,
    "ETH, lastTradeTime:",
    now
  );
}
