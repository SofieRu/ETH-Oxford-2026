# ETH Oxford 2026

<br>

<p align="center">
  <img src="images/Aegis Logo.png" alt="Aegis logo" width="350">
</p>


# _AEGIS_

> Trustless AI trading agents powered by Intel TDX hardware security

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

Users simply send ETH to the bot's wallet address. AEGIS monitors market conditions and autonomously trades ETH ↔ USDC on Uniswap V2 when its strategy signals a favorable opportunity. All of this happens inside the TEE, the decision-making, the key usage, the transaction signing.

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
┌──────────────────── Intel TDX (TEE) ────────────────────────────┐
│                                                                 │
│  1. Generate private key (hardware-derived)                     │
│                                                                 │
│  2. Fetch market data (multi-oracle: CoinGecko + CryptoCompare) │
│                                                                 │
│  3. Strategy: RSI momentum → BUY / SELL / HOLD                  │
│                                                                 │
│  4. Policy check → if allowed, swap ETH ↔ USDC                  │
│                                                                 │
│  5. Sign transaction with TEE-secured key                       │
│                                                                 │
│  Nothing leaves this box except signed transactions.            │
└─────────────────────────────────────────────────────────────────┘
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


## Live demo (hackathon)

**[View Live Dashboard](web/demo-dashboard.html)**

| Item | Value |
|------|--------|
| **App ID** | `rofl1qp9lm376wkqzce2w9nxg5fy3yrn3wqnrv5ang45w` |
| **Network** | Oasis Sapphire Testnet |
| **TEE** | Intel TDX (Oasis ROFL) |
| **Wallet** | See `attestation-report.md` or run `npm run extract-attestation` in `backend/tee-agent` (wallet may need manual add from `oasis rofl machine logs default`) |
| **Status Dashboard** | [Open web/demo-dashboard.html](web/demo-dashboard.html) |

**Note:** The ROFL app runs on Oasis Sapphire Testnet, but the agent executes trades on Base Sepolia.

Verification: see **attestation-report.md** and **DEPLOYMENT.md** in this repo.

To view live agent logs (requires Oasis CLI):

```bash
# From repo root
oasis rofl machine logs default | tail -50
```

<br>

## Tech Stack

| Component | Technology |
|---|---|
| TEE Runtime | [Oasis ROFL](https://docs.oasis.io/build/rofl/) on Intel TDX |
| Blockchain | Base Sepolia (Ethereum L2) |
| DEX | Uniswap V2 (Base Sepolia) |
| Strategy | RSI momentum (CoinGecko + CryptoCompare oracles) |
| Language | TypeScript / Node.js |
| Market Data | CoinGecko API (free, no key) |


<br>

## How to run it

### TEE agent


```bash
git clone https://github.com/SofieRu/ETH-Oxford-2026.git
cd ETH-Oxford-2026/backend/tee-agent
npm install
cp .env.example .env   # set RPC_URL, WETH_ADDRESS, USDC_ADDRESS, WALLET_PASSPHRASE
npx ts-node src/main.ts
```

Create `.env` from `.env.example` with at least:
- `RPC_URL` (e.g. `https://sepolia.base.org`)
- `WETH_ADDRESS`, `USDC_ADDRESS` (token addresses for your chain)
- `WALLET_PASSPHRASE` (used to encrypt/decrypt `wallet.enc`)

On first run the agent creates `wallet.enc`; fund that address with test ETH. No private key is ever stored in plaintext.

### View Status Dashboard

Open the live status dashboard in your browser:

```bash
cd web
open demo-dashboard.html  # macOS
start demo-dashboard.html # Windows
```

No server required — it's a static HTML page showing real-time agent status.

<br>

## Deploy to TEE (Production)

See **[DEPLOYMENT.md](DEPLOYMENT.md)** for full steps. Quick version:

Prerequisites: [Docker](https://docs.docker.com/get-docker/), [Oasis CLI](https://docs.oasis.io/build/tools/oasis-cli/)

```bash
# From repo root: build and push
docker build --platform linux/amd64 -t yourusername/trading-bot:latest .
docker push yourusername/trading-bot:latest

# From backend/tee-agent: one-command deploy (or run oasis commands from repo root)
cd backend/tee-agent && npm run deploy
```

When running inside the TEE, the agent uses the sealed wallet (`wallet.enc` + `WALLET_PASSPHRASE`); keys never leave the enclave.



## Repository Structure

```
ETH-Oxford-2026/
├── backend/
│   └── tee-agent/              # TEE trading agent
│       ├── src/                # TypeScript source code
│       │   ├── main.ts         # Main orchestrator
│       │   ├── wallet.ts       # Encrypted wallet management
│       │   ├── strategy.ts     # RSI trading strategy
│       │   ├── policy.ts       # Safety policy enforcement
│       │   └── trader.ts       # Uniswap V2 execution
│       ├── scripts/            # Deployment automation
│       │   ├── deploy.ts       # One-command deployment
│       │   └── extract-attestation.ts  # Attestation extraction
│       ├── BACKEND-CONFIG.md   # Backend configuration docs
│       ├── package.json        # Dependencies & scripts
│       └── .env.example        # Environment template
├── web/
│   └── demo-dashboard.html     # Live status dashboard
├── images/
│   └── Aegis Logo*.png         # Project branding
├── attestation.json            # Machine-readable attestation
├── attestation.txt             # Quick reference attestation
├── attestation-report.md       # Human-readable attestation proof
├── Dockerfile                  # Container for ROFL deployment
├── compose.yaml                # Docker Compose for Oasis ROFL
├── rofl.yaml                   # ROFL app manifest (Intel TDX)
├── README.md                   # This file
└── DEPLOYMENT.md               # Detailed deployment guide
```

## Key Innovation

The agent **never** reads a raw private key. Locally it uses a passphrase-encrypted `wallet.enc` (AES-256-CBC); in the TEE the same file can be sealed in the enclave. The private key is generated inside the process (hardware entropy), encrypted, and only used for signing—never exported or logged. No `PRIVATE_KEY` in env; no backdoor.


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

## Contact

- **Sofie Rüffer** — [@SofieRu](https://github.com/SofieRu)
- **Matthew Wilson** — [@mattwilsomo](https://github.com/mattwilsomo)
- **Aakash Gnanavelu** — [@AakashGnanavelu](https://github.com/AakashGnanavelu)

For questions about this project, please open an issue on GitHub.

## Acknowledgement

We used generative AI tools to write, review, and develop code, including ChatGPT 5.2 (OpenAI, 2025), Gemini 3 (Google, 2025), and Claude 4.6 (Anthropic, 2025). The company logo was also created using Nano Banana Pro (Google, 2025). 
