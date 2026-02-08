/**
 * Loads .env from the tee-agent package root (backend/tee-agent/.env).
 * This ensures the TEE-ready config is always used, regardless of process.cwd(),
 * and prevents the legacy root .env (PRIVATE_KEY, wrong RPC) from being used.
 */
import path from "path";
import { config } from "dotenv";

// __dirname is the directory of this file (src/ when dev, dist/ when built)
const envPath = path.join(__dirname, "..", ".env");
config({ path: envPath });
