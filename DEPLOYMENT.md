# AEGIS TEE Deployment Guide

Step-by-step instructions to build, push, and deploy the trading agent to Oasis ROFL (Intel TDX TEE).

## Prerequisites

- **Docker** (Linux or Docker Desktop with WSL2 on Windows): [Get Docker](https://docs.docker.com/get-docker/)
- **Oasis CLI** (v0.18.3): [Install guide](https://docs.oasis.io/build/tools/oasis-cli/)
- **WSL** (Windows only): Oasis CLI runs in WSL; [install WSL](https://docs.microsoft.com/en-us/windows/wsl/install)
- **Funded wallet**: Create or use an existing wallet; seal it with `WALLET_PASSPHRASE` and place `wallet.enc` in the TEE data volume (see below).

## 1. Configure environment

```bash
cd backend/tee-agent
cp .env.example .env
# Edit .env: set RPC_URL, WETH_ADDRESS, USDC_ADDRESS, WALLET_PASSPHRASE, etc.
```

Ensure `wallet.enc` exists (run the agent once locally to generate, or copy an existing sealed wallet into `backend/tee-agent/` or `backend/tee-agent/data/`).

## 2. Build and push Docker image

From **repository root**:

```bash
docker build --platform linux/amd64 -t YOUR_DOCKER_USERNAME/trading-bot:latest .
docker push YOUR_DOCKER_USERNAME/trading-bot:latest
```

Update `compose.yaml` so `image` uses your Docker Hub username (or set `DOCKER_USERNAME` when using the deploy script).

## 3. Deploy via Oasis ROFL (automated)

From **backend/tee-agent**:

```bash
npm run deploy
```

This script (WSL-aware on Windows):

1. Builds the Docker image (from repo root)
2. Pushes to Docker Hub
3. Runs `oasis rofl build --force`
4. Runs `oasis rofl update --account my_wallet`
5. Runs `oasis rofl deploy --account my_wallet --force`

You may be prompted for your Oasis wallet passphrase. Set `DOCKER_USERNAME` (and optionally `DOCKER_PASSWORD`, `OASIS_ACCOUNT`) to reduce prompts.

## 4. Deploy via Oasis ROFL (manual)

From repository root:

```bash
oasis rofl build --force
oasis rofl update --account my_wallet
oasis rofl deploy --account my_wallet --force
```

## 5. Wallet and secrets in the TEE

- **Wallet file**: In ROFL, the compose service mounts a volume (e.g. `/storage/bot-data`) to `/app/data`. The agent expects `WALLET_KEY_FILE=/app/data/wallet.enc`. You must place a sealed `wallet.enc` (created with your `WALLET_PASSPHRASE`) into that volume on the TEE host, or ensure the first run generates it and you fund that address.
- **Passphrase**: `WALLET_PASSPHRASE` must be available inside the container (e.g. via Oasis ROFL secrets or env injection). The Dockerfile currently copies `.env` into the image; for production TEE, prefer injecting only non-secret env and the passphrase via a secure channel.

## 6. Extract attestation (for judges / verification)

From **backend/tee-agent**:

```bash
npm run extract-attestation
```

Writes to repo root:

- `attestation.json` — machine-readable
- `attestation-report.md` — human-readable report
- `attestation.txt` — quick view

If **Wallet** shows "(not found)", the script could not parse the wallet from `oasis rofl machine logs default`. You can add the wallet address manually to these files or run `oasis rofl machine logs default` and paste the address from the `[main] Wallet: 0x...` line.

## 7. Useful commands

```bash
# Logs from the TEE machine
oasis rofl machine logs default

# Machine status
oasis rofl machine show default

# List deployments
oasis rofl deployment list
```

## Reference

- **App ID** (example): `rofl1qp9lm376wkqzce2w9nxg5fy3yrn3wqnrv5ang45w`
- **Network**: Oasis Sapphire Testnet
- **rofl.yaml**: Defines TEE type (Intel TDX), resources, and deployment targets.
