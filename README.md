# ETH-Oxford-2026 — Programmable Cryptography Track

# TEE-Secured Autonomous Trading Bot

An autonomous trading bot that generates its own private keys inside a Trusted Execution Environment (TEE). Nobody can access user funds.

## The Problem

Every trading bot today asks you to hand over your private key or deposit funds into a developer-controlled wallet. You're trusting strangers not to steal your money.

## Our Solution

Aegis runs inside an **Intel TDX Trusted Execution Environment** via [Oasis ROFL](https://docs.oasis.io/build/rofl/). The bot's private key is born inside the TEE and never leaves. 

## How It Works

```
┌─────────────────────────────────────────────────┐
│  Intel TDX — Trusted Execution Environment      │
│                                                 │
│  ┌──────────┐   ┌──────────┐   ┌─────────────┐  │
│  │ Key Gen  │   │ Strategy │   │ Swap on     │  │
│  │ (hw-     │   │ Engine   │   │ Uniswap V3  │  │
│  │  derived)│──▶│ (5 signal│──▶│   (Base     │  │
│  │          │   │ heurist) │   │  Sepolia)   │  │
│  └──────────┘   └──────────┘   └─────────────┘  │
│   Never leaves    Auditable      On-chain       │
│   the enclave     decisions        proof        │
└─────────────────────────────────────────────────┘
```

1. **TEE generates a private key** — hardware-isolated, inaccessible to anyone
2. **Strategy engine evaluates 5 market signals** — price momentum, volume, volatility, trend, market cap
3. **If conditions are met → executes swap** on Uniswap V3 (Base Sepolia)
4. **Remote attestation proves** the exact code running inside the TEE

## Tech Stack

| Component | Technology |
|---|---|
| TEE Runtime | [Oasis ROFL](https://docs.oasis.io/build/rofl/) on Intel TDX |
| Blockchain | Base Sepolia (Ethereum L2) |
| DEX | Uniswap V3 |
| Strategy | 5-signal heuristic engine (weighted scoring) |
| Language | Node.js (ES modules) |
| Market Data | CoinGecko API (free, no key) |

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
```
🔐 Key generated INSIDE TEE — hardware-secured, inaccessible to developers
```

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

## Project Structure

```
vaultbot/
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

## License

MIT
