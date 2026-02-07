import axios from "axios";

const COINGECKO_BASE = "https://api.coingecko.com/api/v3";
const ETH_COIN_ID = "ethereum";

/** Single price data point (timestamp in seconds, price in USD). */
export interface PriceData {
  timestamp: number;
  price: number;
}

/** Trading signal produced by the strategy. */
export interface TradingSignal {
  action: "BUY" | "SELL" | "HOLD";
  amount: number;
  price: number;
  rsi: number;
  reason: string;
  timestamp: number;
}

function getRsiPeriod(): number {
  const n = process.env.RSI_PERIOD;
  if (n === undefined) return 14;
  const parsed = parseInt(n, 10);
  return Number.isNaN(parsed) ? 14 : parsed;
}

function getRsiOversold(): number {
  const n = process.env.RSI_OVERSOLD;
  if (n === undefined) return 30;
  const parsed = parseInt(n, 10);
  return Number.isNaN(parsed) ? 30 : parsed;
}

function getRsiOverbought(): number {
  const n = process.env.RSI_OVERBOUGHT;
  if (n === undefined) return 70;
  const parsed = parseInt(n, 10);
  return Number.isNaN(parsed) ? 70 : parsed;
}

function getMaxTradeSizeEth(): number {
  const n = process.env.MAX_TRADE_SIZE_ETH;
  if (n === undefined) return 0.5;
  const parsed = parseFloat(n);
  return Number.isNaN(parsed) ? 0.5 : parsed;
}

/**
 * Fetches current ETH/USD price from CoinGecko simple price API.
 */
export async function fetchCurrentPrice(): Promise<number> {
  console.log("[strategy] Fetching current ETH/USD price from CoinGecko...");
  const url = `${COINGECKO_BASE}/simple/price?ids=${ETH_COIN_ID}&vs_currencies=usd`;
  const res = await axios.get<{ ethereum: { usd: number } }>(url);
  const price = res.data?.ethereum?.usd;
  if (typeof price !== "number") {
    throw new Error("Invalid response from CoinGecko: missing ethereum.usd");
  }
  console.log("[strategy] Current ETH/USD price:", price);
  return price;
}

/**
 * Fetches historical hourly ETH/USD prices from CoinGecko market_chart.
 * Returns at least 24 hours of data for RSI (requests 2 days to be safe).
 */
export async function fetchHistoricalPrices(days: number = 2): Promise<PriceData[]> {
  console.log("[strategy] Fetching historical ETH/USD prices (days =", days, ")...");
  const url = `${COINGECKO_BASE}/coins/${ETH_COIN_ID}/market_chart?vs_currency=usd&days=${days}`;
  const res = await axios.get<{ prices: [number, number][] }>(url);
  const raw = res.data?.prices;
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new Error("Invalid response from CoinGecko: missing or empty prices");
  }
  const points: PriceData[] = raw.map(([tsMs, price]) => ({
    timestamp: Math.floor(tsMs / 1000),
    price,
  }));
  // Sort by timestamp ascending (oldest first) for RSI
  points.sort((a, b) => a.timestamp - b.timestamp);
  console.log("[strategy] Fetched", points.length, "historical price points");
  if (points.length < 24) {
    console.log("[strategy] Warning: fewer than 24 data points; RSI may be less accurate.");
  }
  return points;
}

/**
 * Calculates RSI (Relative Strength Index) from an array of prices.
 * Uses the standard formula: RSI = 100 - (100 / (1 + RS)), where
 * RS = average gain / average loss over the given period.
 */
export function calculateRSI(prices: number[], period: number = 14): number {
  if (prices.length < period + 1) {
    throw new Error(`Need at least ${period + 1} prices for RSI(period=${period}), got ${prices.length}`);
  }
  const changes: number[] = [];
  for (let i = 1; i < prices.length; i++) {
    changes.push(prices[i]! - prices[i - 1]!);
  }
  const lastChanges = changes.slice(-period);
  let sumGain = 0;
  let sumLoss = 0;
  for (const ch of lastChanges) {
    if (ch > 0) sumGain += ch;
    else sumLoss += Math.abs(ch);
  }
  const avgGain = sumGain / period;
  const avgLoss = sumLoss / period;
  if (avgLoss === 0) {
    return 100;
  }
  const rs = avgGain / avgLoss;
  const rsi = 100 - 100 / (1 + rs);
  return Math.round(rsi * 100) / 100;
}

/**
 * Generates a trading signal from current price, historical data, and RSI.
 * BUY when RSI < RSI_OVERSOLD, SELL when RSI > RSI_OVERBOUGHT, else HOLD.
 * Uses env: RSI_PERIOD, RSI_OVERSOLD, RSI_OVERBOUGHT, MAX_TRADE_SIZE_ETH.
 */
export async function generateSignal(): Promise<TradingSignal> {
  const now = Math.floor(Date.now() / 1000);
  console.log("[strategy] Generating signal...");

  const price = await fetchCurrentPrice();
  const historical = await fetchHistoricalPrices(2);
  const priceValues = historical.map((p) => p.price);

  const period = getRsiPeriod();
  const oversold = getRsiOversold();
  const overbought = getRsiOverbought();
  const amountEth = getMaxTradeSizeEth();

  const rsi = calculateRSI(priceValues, period);
  console.log("[strategy] RSI(", period, ") =", rsi, "(oversold <", oversold, ", overbought >", overbought, ")");

  let action: "BUY" | "SELL" | "HOLD";
  let reason: string;

  if (rsi < oversold) {
    action = "BUY";
    reason = `RSI ${rsi} below oversold threshold ${oversold}`;
    console.log("[strategy] Signal: BUY —", reason);
  } else if (rsi > overbought) {
    action = "SELL";
    reason = `RSI ${rsi} above overbought threshold ${overbought}`;
    console.log("[strategy] Signal: SELL —", reason);
  } else {
    action = "HOLD";
    reason = `RSI ${rsi} in neutral range [${oversold}, ${overbought}]`;
    console.log("[strategy] Signal: HOLD —", reason);
  }

  const amount = action === "HOLD" ? 0 : amountEth;

  return {
    action,
    amount,
    price,
    rsi,
    reason,
    timestamp: now,
  };
}
