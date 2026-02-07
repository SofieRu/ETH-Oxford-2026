# ETH Oxford 2026

<p align="center">
  <img src="images/Logo_Final.png" alt="Haikara logo" width="330">
</p>


# _AEGIS_

### Team Members  
Sofie Rüffer  
Matthew Wilson   
Aakash Gnanavelu    

<br>

## The Problem

Every trading bot today asks you to hand over your private key or deposit funds into a developer-controlled wallet. You're trusting strangers not to steal your money.

<br>

## Our Solution

Here, we built _AEGIS_, an autonomous trading bot that generates its own private keys inside an **Intel TDX Trusted Execution Environment** (TEE) via [Oasis ROFL](https://docs.oasis.io/build/rofl/). This means that nobody can access user funds, not even us.

It generates its own private key inside the TEE. That key is used to create a wallet and sign transactions but the key itself never leaves the hardware. There is no API to extract it, no admin backdoor and no way to access it. 

Users simply send ETH to the bot's wallet address. AEGIS monitors market conditions and autonomously trades ETH ↔ USDC on Uniswap V3 when its strategy signals a favorable opportunity. All of this happens inside the TEE, the decision-making, the key usage, the transaction signing.

<br>

## How It Works

```
                      User sends ETH
                            │
                            ▼
┌──────────────────── Intel TDX (TEE) ──────────────────┐
│                                                       │
│  1. Generate private key (hardware-derived)           │
│                                                       │
│  2. Fetch market data (price, volume, volatility)     │
│                                                       │
│  3. Strategy engine scores 5 signals                  │
│                                                       │
│  4. If score ≥ threshold → swap ETH ↔ USDC            │
│                                                       │
│  5. Sign transaction with TEE-secured key             │
│                                                       │
│  Nothing leaves this box except signed transactions.  │
└───────────────────────────────────────────────────────┘
                            │
                            ▼
    Transaction on Base Sepolia (verifiable on-chain)

```

## Tech Stack

| Component | Technology |
|---|---|
| TEE Runtime | [Oasis ROFL](https://docs.oasis.io/build/rofl/) on Intel TDX |
| Blockchain | Base Sepolia (Ethereum L2) |
| DEX | Uniswap V3 |
| Strategy | 5-signal heuristic engine (weighted scoring) |
| Language | Node.js (ES modules) |
| Market Data | CoinGecko API (free, no key) |


## Why TEE?

With traditional bots,the developer holds your private key and the decision logic is a black box. Using TEEs we are able to generate a key inside hardware, meaning that theft is impossible. Additionally, auditable logs are produced inside the TEE.

| Traditional Bot | AEGIS (TEE-Secured) |
|---|---|
| Developer holds your private key | Key generated inside hardware, developer never sees it |
| You trust the developer won't steal funds | Theft is **physically impossible** — enforced by the chip |
| No way to verify what code is running | **Remote attestation** cryptographically proves the exact code |
| Decision logic is a black box | Auditable logs produced inside the TEE |

<br>

## Strategy Engine

The heuristic engine evaluates 5 weighted signals from CoinGecko:

| Signal | Weight | Logic |
|---|---|---|
| 24h Price Change | 30% | Momentum indicator |
| 7d Price Change | 20% | Trend direction |
| Volume Change | 25% | Market activity |
| Volatility | 15% | Risk assessment |
| Market Cap Rank | 10% | Asset quality |

Combined score ≥ 30 → **SWAP** · Score < 30 → **HOLD**

<br>

## Quick Start (Local Dev)

```bash
git clone https://github.com/...
cd tee-bot
npm install
```

Create a `.env` file:
```
PRIVATE_KEY=your_test_wallet_private_key
RPC_URL=https://sepolia.base.org
```

Run the bot:
```bash
node bot.js
```

Expected output:
```
Using local .env key (NOT secure — dev mode only)
Wallet: 0xA77b...9837
Balance: 0.0 ETH
Pool found: 0x94bf...eC0 (fee: 500)
ETH: $2040.42 (24h: -0.07%, 7d: -17.77%)
Strategy Decision: HOLD (score: -13, confidence: 13%)
```

## Deploy to TEE (Production)

Prerequisites: [Docker](https://docs.docker.com/get-docker/), [Oasis CLI](https://docs.oasis.io/build/tools/oasis-cli/)

```bash
# Build the container
docker build --platform linux/amd64 -t yourusername/trading-bot:latest .
docker push yourusername/trading-bot:latest

# Register and deploy to Oasis ROFL
oasis rofl build --force
oasis rofl create --account myaccount
oasis rofl deploy --account myaccount
```

When running inside the TEE, the bot automatically switches to hardware-derived key generation:



## Repository Structure

```
├── bot.js           # Main bot — TEE key gen + trading loop
├── strategy.js      # 5-signal heuristic decision engine
├── Dockerfile       # Container for ROFL deployment
├── compose.yaml     # Docker Compose for Oasis ROFL
├── rofl.yaml        # ROFL app manifest
├── .env.example     # Template for local dev secrets
├── package.json     # Dependencies
└── .gitignore       # Excludes node_modules, .env, *.orc
```

## Key Innovation

```javascript
async function getPrivateKey() {
    if (existsSync("/run/rofl-appd.sock")) {
        // Inside TEE → hardware-generated key
        const client = new RoflClient();
        return await client.generateKey("trading-bot-key", KeyKind.SECP256K1);
    }
    // Local dev → .env key
    return process.env.PRIVATE_KEY;
}
```

The same codebase runs in both dev and production. In the TEE, keys are derived from hardware, so they never exist outside the encrypted enclave.

## Verification

- **ROFL App ID:** `rofl1qqqlx299mq4ggeq3gfh5nkxztxxks595nczzeke5`
- **Docker Image:** `docker.io/sofieru/trading-bot:latest`
- **Bot Wallet:** `0xA77b7b47056c3e66bB1fa2d2131E3e867a079837`
- **Network:** Oasis Sapphire Testnet + Base Sepolia

## Team

Built at ETH Oxford 2026

---

## Backend Architecture

### Overview
The backend implements a trustless AI trading agent with hardware-enforced security guarantees. All core modules are complete, tested, and ready for TEE deployment.

### Core Modules

#### 1. Wallet Module (`src/wallet.ts`)
**Purpose:** Secure private key management with TEE-ready architecture

**Features:**
- Hardware entropy-based key generation (`crypto.randomBytes`)
- AES-256-CBC encryption for key storage
- Sealed storage (keys encrypted at rest)
- Transaction signing without key exposure
- Balance checking and address management

**Security Properties:**
- Private keys never logged or exported
- Keys encrypted with hardware-derived secrets
- Production-ready for TEE deployment (Oasis ROFL)

**Test:** `npx ts-node src/test-wallet.ts`

---

#### 2. Strategy Module (`src/strategy.ts`)
**Purpose:** Market analysis and trading signal generation

**Features:**
- Multi-oracle price consensus (CoinGecko + CryptoCompare)
- RSI (Relative Strength Index) momentum indicator
- Configurable oversold/overbought thresholds
- Historical data analysis (7 days of hourly candles)
- Oracle disagreement detection (2% spread tolerance)

**Trading Logic:**
- RSI < 30 → BUY signal (oversold)
- RSI > 70 → SELL signal (overbought)  
- RSI 30-70 → HOLD (neutral)

**Test:** `npx ts-node src/test-strategy.ts`

---

#### 3. Policy Module (`src/policy.ts`)
**Purpose:** Safety enforcement and risk management

**Features:**
- Maximum trade size limits
- Daily trading volume caps
- Rate limiting (minimum interval between trades)
- Token whitelist enforcement
- Emergency stop mechanism
- Daily volume reset at midnight

**Policy Checks:**
1. Emergency stop status
2. Trade size validation
3. Daily limit verification
4. Rate limit enforcement
5. Token whitelist check

**This is where "unruggable" is enforced** - these checks run inside the TEE where even the developer cannot bypass them.

**Test:** `npx ts-node src/test-policy.ts`

---

#### 4. Trader Module (`src/trader.ts`)
**Purpose:** DEX integration and swap execution

**Features:**
- Uniswap V2 integration
- Transaction construction for swaps
- Slippage tolerance calculation
- Gas price estimation
- Path routing (ETH ↔ USDC)

**Supported Operations:**
- BUY: Swap ETH → USDC
- SELL: Swap USDC → ETH

**Networks Supported:**
- Sepolia (testnet)
- Base Sepolia (testnet)
- Easily configurable for other EVM chains

**Test:** `npx ts-node src/test-trader.ts`

---

#### 5. Main Orchestrator (`src/main.ts`)
**Purpose:** Integration layer that ties all modules together

**Features:**
- Continuous trading loop
- Module coordination (wallet → strategy → policy → trader)
- Error handling and recovery
- Configurable check intervals
- Graceful shutdown

**Flow:**
1. Generate trading signal (strategy module)
2. Check policy constraints (policy module)
3. If approved, execute swap (trader module)
4. Wait for configured interval
5. Repeat

**Test:** `npx ts-node src/test-main.ts`

---

### Configuration

All modules are configured via environment variables in `.env`:

```bash
# Network
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
CHAIN_ID=11155111

# Token addresses (Sepolia / Base Sepolia)
WETH_ADDRESS=0x...
USDC_ADDRESS=0x...

# Policy
MAX_TRADE_SIZE_ETH=0.5
DAILY_LIMIT_ETH=2.0
MIN_TRADE_INTERVAL_SECONDS=600
MAX_SLIPPAGE_PERCENT=2.0
EMERGENCY_STOP=0

# Strategy (RSI)
RSI_PERIOD=14
RSI_OVERSOLD=30
RSI_OVERBOUGHT=70

# Wallet
WALLET_PASSPHRASE=your-secure-passphrase
WALLET_KEY_FILE=wallet.enc

# Optional
TRADE_CHECK_INTERVAL_MS=600000
MOCK_PRICES=0
PRICE_API_BASE_URL=
```

Run the agent from `backend/tee-agent`:
```bash
cd backend/tee-agent
npm install
npx ts-node src/main.ts
```

---

## License

MIT
