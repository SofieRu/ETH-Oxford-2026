# ETH Oxford 2026

<br>

<p align="center">
  <img src="images/Aegis Logo.png" alt="Aegis logo" width="350">
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

## Why TEE?

| Traditional Bot | AEGIS (TEE-Secured) |
|---|---|
| Developer holds your private key | Key generated inside hardware, developer never sees it |
| You trust the developer won't steal funds | Theft is **physically impossible** — enforced by the chip |
| No way to verify what code is running | **Remote attestation** cryptographically proves the exact code |
| Decision logic is a black box | Auditable logs produced inside the TEE |

<br>

## Architecture 

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

<br>

AEGIS is built as **5 modules** that run in sequence every cycle:

**1. Wallet:** Generates and manages private keys with hardware entropy. Keys are encrypted at rest using AES-256-CBC and never logged or exported. In the TEE, keys are derived from hardware. Outside, they are derived from a passphrase-encrypted file.

**2. Strategy:** Pulls price data from two independent oracles (CoinGecko + CryptoCompare) and computes RSI over 7 days of hourly candles. If the oracles disagree by more than 2%, the bot holds as a safety measure.

| RSI Value | Signal |
|---|---|
| Below 30 | BUY (oversold) |
| Above 70 | SELL (overbought) |
| 30 – 70 | HOLD (neutral) |

**3. Policy:** A safety layer that runs inside the TEE, that encodes maximum trade size per swap, daily trading volume cap (resets at midnight), rate limiting between trades, token whitelist (only approved pairs) and emergency stop switch.

**4. Trader:** Constructs and submits swaps on Uniswap V2 with configurable slippage tolerance, gas estimation, and ETH ↔ USDC path routing. Supports Sepolia, Base Sepolia, and any EVM chain.

**5. Orchestrator:** Ties it all together in a continuous loop: Signal → Policy Check → Execute → Wait → Repeat. Handles errors gracefully and shuts down cleanly.

<br>

## Tech Stack

| Component | Technology |
|---|---|
| TEE Runtime | [Oasis ROFL](https://docs.oasis.io/build/rofl/) on Intel TDX |
| Blockchain | Base Sepolia (Ethereum L2) |
| DEX | Uniswap V3 |
| Strategy | 5-signal heuristic engine (weighted scoring) |
| Language | Node.js (ES modules) |
| Market Data | CoinGecko API (free, no key) |


<br>

## How to run it


```bash
git clone https://github.com/YOUR_TEAM/aegis.git
cd backend/tee-agent
npm install
cp .env.example .env   # configure your keys and settings
npx ts-node src/main.ts
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

<br>

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


<!-- 

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

-->

## License

MIT

## Acknowledgement

We used generative AI tools to write, review, and develop code, including ChatGPT 5.2 (OpenAI, 2025), Gemini 3 (Google, 2025), and Claude 4.6 (Anthropic, 2025). The company logo was also created using Nano Banana Pro (Google, 2025).
