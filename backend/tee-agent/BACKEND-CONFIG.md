# Backend Configuration & TEE-Ready Wallet Consistency

## Summary of Inconsistencies Found and Fixes Applied

### 1. .env loading (root vs backend/tee-agent)

**Problem:** All entry points used `import "dotenv/config"` with no path. Dotenv loads from **process.cwd()**. So:
- Running from `backend/tee-agent` (e.g. `npx ts-node src/main.ts`) → loaded `backend/tee-agent/.env` ✓
- Running from repo root (e.g. `node backend/tee-agent/dist/main.js`) → would load **root `.env`** if present, which can contain legacy `PRIVATE_KEY` and wrong RPC.

**Fix:** Added `src/env-loader.ts` that loads `.env` from the **package root** using `path.join(__dirname, "..", ".env")`. So:
- From `dist/main.js`: `__dirname` is `.../dist` → loads `.../backend/tee-agent/.env`.
- From `src/main.ts` (ts-node): `__dirname` is `.../src` → loads `.../backend/tee-agent/.env`.

All entry points now use `import "./env-loader"` instead of `import "dotenv/config"`, so **only** `backend/tee-agent/.env` is used. Root `.env` is ignored by the tee-agent.

---

### 2. Wallet module (no PRIVATE_KEY; file name and location)

**Verified:**
- `wallet.ts` **never** reads `PRIVATE_KEY`. It only uses `WALLET_PASSPHRASE` and `WALLET_KEY_FILE`.
- `loadWallet()` reads the path from `getWalletPath()` → `process.env.WALLET_KEY_FILE ?? "wallet.enc"`, resolved relative to **process.cwd()** (or absolute if env is absolute).
- Default file name is **`wallet.enc`** (not `sealed_key.enc`). If you prefer `sealed_key.enc`, set `WALLET_KEY_FILE=sealed_key.enc` or `WALLET_KEY_FILE=data/sealed_key.enc` in `backend/tee-agent/.env`.
- `initWallet()`: if the file exists → `loadWallet()`; else → `generateWallet()`. So your existing funded wallet in `wallet.enc` is loaded as long as the path and passphrase are correct.

**Docker:** Previously the wallet was written to `/app/wallet.enc` (cwd in container = `/app`), while the volume mount was `./backend/tee-agent/data:/app/data`. So the wallet did **not** persist in the mounted folder.

**Fix:**
- In **Dockerfile**: `ENV WALLET_KEY_FILE=/app/data/wallet.enc` so the wallet lives in the data directory.
- In **compose.yaml**: `environment: WALLET_KEY_FILE=/app/data/wallet.enc` (same) and volume `./backend/tee-agent/data:/app/data` kept. So the sealed wallet is stored in `backend/tee-agent/data/wallet.enc` on the host and persists across container restarts.

**If your funded wallet is currently at `backend/tee-agent/wallet.enc`:**  
Copy it into the data folder so Docker uses it:
```bash
mkdir -p backend/tee-agent/data
cp backend/tee-agent/wallet.enc backend/tee-agent/data/wallet.enc
```
Then run with compose; the same passphrase in `backend/tee-agent/.env` will decrypt it.

---

### 3. RPC URL (Alchemy Sepolia vs Base Sepolia)

**Problem:**
- `backend/tee-agent/.env` has `RPC_URL=https://eth-sepolia.g.alchemy.com/v2/...` (Ethereum Sepolia, correct for funded wallet).
- **compose.yaml** had `environment: RPC_URL=https://sepolia.base.org` → this **overrode** the .env and forced Base Sepolia.
- **test-trader.ts** had fallback `process.env.RPC_URL ?? "https://sepolia.base.org"` → if RPC_URL was ever missing, it would use Base Sepolia instead of failing.

**Fix:**
- **compose.yaml**: Removed the RPC override. Added `env_file: ./backend/tee-agent/.env` so the container uses your Alchemy Sepolia RPC (and all other vars) from that file.
- **test-trader.ts**: No fallback; if `RPC_URL` is missing, the script exits with "RPC_URL is not set in backend/tee-agent/.env".

---

### 4. Docker & Compose (volumes and env)

**Changes made:**
- **Dockerfile**: `ENV WALLET_KEY_FILE=/app/data/wallet.enc` so the default in-container path is the data directory.
- **compose.yaml**:
  - `env_file: ./backend/tee-agent/.env` so one source of truth (TEE-ready config).
  - Volume `./backend/tee-agent/data:/app/data` kept for wallet persistence.
  - `environment: WALLET_KEY_FILE=/app/data/wallet.enc` so the agent uses the mounted data dir.
  - Removed `RPC_URL=https://sepolia.base.org` so RPC comes from `backend/tee-agent/.env`.

---

## Checklist: Ensure Only Your TEE-Ready Wallet Is Used

1. **Use only `backend/tee-agent/.env`**
   - All tee-agent entry points now load it via `env-loader.ts`. Do not rely on root `.env` for the agent.
   - Optional: delete or rename root `.env` so nothing accidentally uses `PRIVATE_KEY` from it.

2. **Wallet file location**
   - **Local run (from `backend/tee-agent`):** Default is `wallet.enc` in `backend/tee-agent/`. Put your funded sealed wallet there and set `WALLET_PASSPHRASE` in `backend/tee-agent/.env`.
   - **Docker (compose):** Wallet path is `backend/tee-agent/data/wallet.enc`. Copy `wallet.enc` into `backend/tee-agent/data/` if it’s currently in `backend/tee-agent/`, then run `docker compose up`.

3. **RPC**
   - Keep `RPC_URL` in `backend/tee-agent/.env` pointing to your Alchemy Ethereum Sepolia (or same network as the funded wallet). Compose no longer overrides it.

4. **Verify**
   - From repo root or from `backend/tee-agent`:
     ```bash
     cd backend/tee-agent
     npx ts-node src/test-wallet.ts
     ```
     You should see the **same** address as your funded wallet. If a new wallet is created, the path or passphrase is wrong, or the sealed file wasn’t found.

---

## File Reference

| Item              | Location / value |
|-------------------|-------------------|
| TEE-ready .env    | `backend/tee-agent/.env` |
| Env loader        | `backend/tee-agent/src/env-loader.ts` |
| Wallet default file | `wallet.enc` (or `WALLET_KEY_FILE`) |
| Docker wallet path | `/app/data/wallet.enc` → host `backend/tee-agent/data/wallet.enc` |
| RPC source in Docker | `env_file: ./backend/tee-agent/.env` (no override) |
