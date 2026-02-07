import axios from "axios";

// --- Config ---
const SWAP_THRESHOLD = 30;  // combined score above this → SWAP

// --- Signal weights (how much each signal matters) ---
const WEIGHTS = {
	priceChange24h: 0.30,
	priceChange7d:  0.20,
	volumeChange:   0.25,
	volatility:     0.15,
	marketCapRank:  0.10
};

// --- Fetch market data from CoinGecko ---
async function fetchMarketData() {
	const url = "https://api.coingecko.com/api/v3/coins/ethereum?localization=false&tickers=false&community_data=false&developer_data=false";
	const response = await axios.get(url);
	const data = response.data;

	return {
		price: data.market_data.current_price.usd,
		priceChange24h: data.market_data.price_change_percentage_24h,
		priceChange7d: data.market_data.price_change_percentage_7d,
		volume24h: data.market_data.total_volume.usd,
		marketCap: data.market_data.market_cap.usd,
		marketCapRank: data.market_cap_rank,
		high24h: data.market_data.high_24h.usd,
		low24h: data.market_data.low_24h.usd
	};
}

// --- Individual signal scorers (each returns -100 to +100) ---

function scorePriceChange24h(change) {
	// Big rise = good time to lock profits into USDC
	// Big drop = hold, don't sell low
	if (change > 10) return 100;
	if (change > 5)  return 70;
	if (change > 2)  return 40;
	if (change > 0)  return 10;
	if (change > -2) return -10;
	if (change > -5) return -40;
	return -70;
}

function scorePriceChange7d(change) {
	// Weekly uptrend = potential peak, consider swapping
	// Weekly downtrend = not a good time to swap
	if (change > 15) return 100;
	if (change > 8)  return 60;
	if (change > 3)  return 30;
	if (change > 0)  return 10;
	if (change > -3) return -10;
	if (change > -8) return -40;
	return -60;
}

function scoreVolume(priceChange, volumeChange) {
	// Price up + high volume = strong move, good time to swap
	// Price up + low volume = weak move, risky to swap
	if (priceChange > 0 && volumeChange > 50) return 80;
	if (priceChange > 0 && volumeChange > 20) return 50;
	if (priceChange > 0) return 20;
	if (priceChange < 0 && volumeChange > 50) return -60;
	return -20;
}

function scoreVolatility(high, low, price) {
	// Volatility = how wide the 24h range is vs current price
	const range = ((high - low) / price) * 100;
	// High volatility = risky, maybe lock into stables
	if (range > 10) return 60;
	if (range > 5)  return 30;
	if (range > 2)  return 0;
	return -20;
}

function scoreMarketCapRank(rank) {
	// ETH should be rank 2. If it dropped, something is off.
	if (rank <= 2) return 20;
	if (rank <= 5) return -20;
	return -50;
}

// --- Build reason string ---
function buildReason(signals, action) {
	const parts = [];

	if (signals.priceChange24h > 30) parts.push(`24h price up strongly`);
	else if (signals.priceChange24h < -30) parts.push(`24h price dropping`);

	if (signals.priceChange7d > 30) parts.push(`weekly uptrend`);
	else if (signals.priceChange7d < -30) parts.push(`weekly downtrend`);

	if (signals.volumeChange > 30) parts.push(`volume spike detected`);

	if (signals.volatility > 30) parts.push(`high volatility`);

	if (action === "SWAP") {
		parts.push("locking gains into USDC");
	} else {
		parts.push("conditions not favorable for swap");
	}

	return parts.join(", ");
}

// --- Main evaluate function ---
export async function evaluate() {
	console.log("Fetching market data...");
	const market = await fetchMarketData();

	console.log(`   Price:      $${market.price}`);
	console.log(`   24h Change: ${market.priceChange24h.toFixed(2)}%`);
	console.log(`   7d Change:  ${market.priceChange7d.toFixed(2)}%`);
	console.log(`   24h Range:  $${market.low24h} — $${market.high24h}`);

	// Score each signal
	const signals = {
		priceChange24h: scorePriceChange24h(market.priceChange24h),
		priceChange7d:  scorePriceChange7d(market.priceChange7d),
		volumeChange:   scoreVolume(market.priceChange24h, 30), // simplified for now
		volatility:     scoreVolatility(market.high24h, market.low24h, market.price),
		marketCapRank:  scoreMarketCapRank(market.marketCapRank)
	};

	// Weighted combined score
	const combinedScore = Math.round(
		signals.priceChange24h * WEIGHTS.priceChange24h +
		signals.priceChange7d  * WEIGHTS.priceChange7d +
		signals.volumeChange   * WEIGHTS.volumeChange +
		signals.volatility     * WEIGHTS.volatility +
		signals.marketCapRank  * WEIGHTS.marketCapRank
	);

	const action = combinedScore >= SWAP_THRESHOLD ? "SWAP" : "HOLD";
	const confidence = Math.min(100, Math.abs(combinedScore));
	const reason = buildReason(signals, action);

	const decision = {
		action,
		confidence,
		combinedScore,
		reason,
		signals,
		market
	};

	console.log(`\nStrategy Decision:`);
	console.log(`   Signals:    ${JSON.stringify(signals)}`);
	console.log(`   Score:      ${combinedScore} (threshold: ${SWAP_THRESHOLD})`);
	console.log(`   Action:     ${action}`);
	console.log(`   Confidence: ${confidence}%`);
	console.log(`   Reason:     ${reason}`);

	return decision;
}

