import axios from "axios";

const DEFAULT_COINGECKO_BASE = "https://api.coingecko.com/api/v3";
const ETH_COIN_ID = "ethereum";

function getPriceApiBase(): string {
  return process.env.PRICE_API_BASE_URL ?? DEFAULT_COINGECKO_BASE;
}

function isMockPrices(): boolean {
  const v = process.env.MOCK_PRICES;
  return v === "1" || v === "true" || v === "yes";
}

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

/** Prices from multiple oracles for consensus. */
export interface OraclePrices {
  coingecko: number;
  cryptocompare: number;
}

const ORACLE_CONSENSUS_THRESHOLD_PERCENT = 2;
const CRYPTOCOMPARE_BASE = "https://min-api.cryptocompare.com/data";

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
 * Returns mock current price (used when MOCK_PRICES=1 or network unavailable).
 */
function getMockCurrentPrice(): number {
  const base = 3500;
  const t = Date.now() / 3600000;
  return Math.round((base + Math.sin(t * 0.1) * 50) * 100) / 100;
}

/**
 * Fetches current ETH/USD price from CoinGecko simple price API.
 * Set MOCK_PRICES=1 to use fake data (no network). Set PRICE_API_BASE_URL to use a proxy.
 */
export async function fetchCurrentPrice(): Promise<number> {
  if (isMockPrices()) {
    const price = getMockCurrentPrice();
    console.log("[strategy] Using mock price (MOCK_PRICES=1):", price);
    return price;
  }
  const base = getPriceApiBase();
  console.log("[strategy] Fetching current ETH/USD price from", base, "...");
  try {
    const url = `${base}/simple/price?ids=${ETH_COIN_ID}&vs_currencies=usd`;
    const res = await axios.get<{ ethereum: { usd: number } }>(url);
    const price = res.data?.ethereum?.usd;
    if (typeof price !== "number") {
      throw new Error("Invalid response: missing ethereum.usd");
    }
    console.log("[strategy] Current ETH/USD price:", price);
    return price;
  } catch (err: unknown) {
    const msg = err && typeof err === "object" && "code" in err ? (err as { code: string }).code : "";
    if (msg === "ENOTFOUND" || msg === "ECONNREFUSED" || msg === "ETIMEDOUT") {
      console.log("[strategy] Network unreachable (", msg, "). Use MOCK_PRICES=1 in .env to run without CoinGecko.");
    }
    throw err;
  }
}

/**
 * Fetches ETH/USD price from CoinGecko only (for multi-oracle).
 */
async function fetchPriceFromCoinGecko(): Promise<number> {
  if (isMockPrices()) return getMockCurrentPrice();
  const base = getPriceApiBase();
  const url = `${base}/simple/price?ids=${ETH_COIN_ID}&vs_currencies=usd`;
  const res = await axios.get<{ ethereum: { usd: number } }>(url);
  const price = res.data?.ethereum?.usd;
  if (typeof price !== "number") throw new Error("CoinGecko: missing ethereum.usd");
  return price;
}

/**
 * Fetches ETH/USD price from CryptoCompare (backup oracle).
 */
async function fetchPriceFromCryptoCompare(): Promise<number> {
  if (isMockPrices()) return getMockCurrentPrice();
  const url = `${CRYPTOCOMPARE_BASE}/price?fsym=ETH&tsyms=USD`;
  const res = await axios.get<{ USD: number }>(url);
  const price = res.data?.USD;
  if (typeof price !== "number") throw new Error("CryptoCompare: missing USD");
  return price;
}

/**
 * Fetches ETH/USD price from multiple oracles (CoinGecko + CryptoCompare).
 * Returns both prices for consensus checks. In mock mode both return the same mock price.
 */
export async function fetchPriceFromMultipleSources(): Promise<OraclePrices> {
  console.log("[strategy] Fetching price from multiple oracles (CoinGecko, CryptoCompare)...");
  if (isMockPrices()) {
    const price = getMockCurrentPrice();
    console.log("[strategy] Using mock prices (MOCK_PRICES=1):", price, "for both sources");
    return { coingecko: price, cryptocompare: price };
  }
  const [coingecko, cryptocompare] = await Promise.all([
    fetchPriceFromCoinGecko(),
    fetchPriceFromCryptoCompare(),
  ]);
  console.log("[strategy] CoinGecko:", coingecko, "| CryptoCompare:", cryptocompare);
  return { coingecko, cryptocompare };
}

/**
 * Returns mock historical prices (~168 hourly points) for offline/dev use.
 */
function getMockHistoricalPrices(days: number): PriceData[] {
  const nowSec = Math.floor(Date.now() / 1000);
  const hour = 3600;
  const points: PriceData[] = [];
  let price = 3480;
  for (let i = days * 24; i >= 0; i--) {
    const ts = nowSec - i * hour;
    price = price + (Math.random() - 0.48) * 40;
    if (price < 3200) price = 3200;
    if (price > 3800) price = 3800;
    points.push({ timestamp: ts, price: Math.round(price * 100) / 100 });
  }
  return points;
}

/**
 * Fetches historical ETH/USD prices from CoinGecko market_chart.
 * Default 7 days gives ~168 data points (hourly granularity) for better RSI smoothing.
 * Set MOCK_PRICES=1 to use fake data (no network).
 */
export async function fetchHistoricalPrices(days: number = 7): Promise<PriceData[]> {
  if (isMockPrices()) {
    const points = getMockHistoricalPrices(days);
    console.log("[strategy] Using mock historical prices (MOCK_PRICES=1):", points.length, "points");
    return points;
  }
  const base = getPriceApiBase();
  console.log("[strategy] Fetching historical ETH/USD prices (days =", days, ")...");
  try {
    const url = `${base}/coins/${ETH_COIN_ID}/market_chart?vs_currency=usd&days=${days}`;
    const res = await axios.get<{ prices: [number, number][] }>(url);
    const raw = res.data?.prices;
    if (!Array.isArray(raw) || raw.length === 0) {
      throw new Error("Invalid response: missing or empty prices");
    }
    const points: PriceData[] = raw.map(([tsMs, price]) => ({
      timestamp: Math.floor(tsMs / 1000),
      price,
    }));
    points.sort((a, b) => a.timestamp - b.timestamp);
    console.log("[strategy] Fetched", points.length, "historical price points");
    if (points.length < 24) {
      console.log("[strategy] Warning: fewer than 24 data points; RSI may be less accurate.");
    }
    return points;
  } catch (err: unknown) {
    const msg = err && typeof err === "object" && "code" in err ? (err as { code: string }).code : "";
    if (msg === "ENOTFOUND" || msg === "ECONNREFUSED" || msg === "ETIMEDOUT") {
      console.log("[strategy] Network unreachable (", msg, "). Use MOCK_PRICES=1 in .env to run without CoinGecko.");
    }
    throw err;
  }
}

/**
 * Calculates RSI (Relative Strength Index) from an array of prices using
 * Wilder's smoothing method. This matches TradingView's RSI calculation:
 * - First period: simple average of gains and losses over the first `period` changes.
 * - Subsequent periods: smoothed average = previousAvg * (period-1)/period + currentValue * 1/period.
 * - RSI = 100 - (100 / (1 + RS)), where RS = smoothedAvgGain / smoothedAvgLoss.
 */
export function calculateRSI(prices: number[], period: number = 14): number {
  if (prices.length < period + 1) {
    throw new Error(`Need at least ${period + 1} prices for RSI(period=${period}), got ${prices.length}`);
  }
  const changes: number[] = [];
  for (let i = 1; i < prices.length; i++) {
    changes.push(prices[i]! - prices[i - 1]!);
  }
  // First period: simple average of gains and losses
  let sumGain = 0;
  let sumLoss = 0;
  for (let i = 0; i < period; i++) {
    const ch = changes[i]!;
    if (ch > 0) sumGain += ch;
    else sumLoss += Math.abs(ch);
  }
  let avgGain = sumGain / period;
  let avgLoss = sumLoss / period;
  // Wilder's smoothing: subsequent periods use previousAvg * (period-1)/period + current * 1/period
  const wilderFactor = (period - 1) / period;
  for (let i = period; i < changes.length; i++) {
    const ch = changes[i]!;
    const currentGain = ch > 0 ? ch : 0;
    const currentLoss = ch < 0 ? Math.abs(ch) : 0;
    avgGain = avgGain * wilderFactor + currentGain / period;
    avgLoss = avgLoss * wilderFactor + currentLoss / period;
  }
  if (avgLoss === 0) {
    return 100;
  }
  const rs = avgGain / avgLoss;
  const rsi = 100 - 100 / (1 + rs);
  return Math.round(rsi * 100) / 100;
}

/**
 * Generates a trading signal from multi-oracle consensus, historical data, and RSI.
 * Only proceeds if CoinGecko and CryptoCompare prices are within 2% (oracle consensus).
 * BUY when RSI < RSI_OVERSOLD, SELL when RSI > RSI_OVERBOUGHT, else HOLD.
 */
export async function generateSignal(): Promise<TradingSignal> {
  const now = Math.floor(Date.now() / 1000);
  console.log("[strategy] Generating signal...");

  const oraclePrices = await fetchPriceFromMultipleSources();
  const { coingecko, cryptocompare } = oraclePrices;
  const mid = (coingecko + cryptocompare) / 2;
  const spread = Math.abs(coingecko - cryptocompare);
  const spreadPercent = mid > 0 ? (spread / mid) * 100 : 0;

  if (spreadPercent > ORACLE_CONSENSUS_THRESHOLD_PERCENT) {
    console.log("[strategy] Oracle disagreement - holding for safety (spread", spreadPercent.toFixed(2), "% >", ORACLE_CONSENSUS_THRESHOLD_PERCENT, "%)");
    return {
      action: "HOLD",
      amount: 0,
      price: mid,
      rsi: 0,
      reason: "Oracle disagreement - holding for safety",
      timestamp: now,
    };
  }

  console.log("[strategy] Oracle consensus: 2/2 sources agree (spread", spreadPercent.toFixed(2), "%)");
  const price = mid;

  const historical = await fetchHistoricalPrices(7);
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
