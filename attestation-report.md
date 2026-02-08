# TEE Attestation Report

## Deployment Information

| Field | Value |
|-------|-------|
| App ID | rofl1qp9lm376wkqzce2w9nxg5fy3yrn3wqnrv5ang45w |
| Machine ID | 000000000000057f |
| TEE Type | Intel TDX |
| Status | accepted |
| Network | Oasis Sapphire Testnet |

## Wallet Address

`0x84F2ff12c1cbCebc73F37386b05c06464ab5e147`

## Deployment Hash

`sha256:c97686c586d1620308ad53baa2aa7f72eb8482d415da5208f0d954e4c4b7dc56`

## Verification Instructions

1. Verify the deployment hash matches the image deployed to the TEE.
2. Confirm the App ID on Oasis explorer (Sapphire Testnet).
3. Check that the wallet address matches the agent's funded wallet.

## Timeline

- **Created:** 2026-02-08 03:52:11 +0000 GMT
- **Expires:** 2026-02-08 04:52:11 +0000 GMT
- **Report extracted:** 2026-02-08T04:23:22.261Z

## What This Proves

- The trading agent is running inside an **Intel TDX** Trusted Execution Environment.
- The exact code (Docker image) is identified by the deployment hash.
- The wallet address is the agent's on-chain identity (keys never leave the TEE).
- Deployment and attestation are verifiable on the Oasis Sapphire Testnet.
