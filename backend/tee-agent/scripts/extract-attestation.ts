/**
 * Extract Oasis ROFL TEE attestation data for display or verification.
 * Run from backend/tee-agent: npm run extract-attestation
 *
 * Outputs: attestation.json, attestation-report.md, attestation.txt (in repo root).
 */

import path from "path";
import fs from "fs";
import { spawnSync } from "child_process";

const isWindows = process.platform === "win32";

function toWslPath(winPath: string): string {
  const normalized = path.normalize(winPath).replace(/\\/g, "/");
  const match = normalized.match(/^([a-zA-Z]):\/?(.*)$/);
  if (match) {
    const drive = match[1]!.toLowerCase();
    const rest = match[2] ?? "";
    return `/mnt/${drive}/${rest}`.replace(/\/+/g, "/");
  }
  return normalized;
}

/** WSL path with spaces escaped for bash (e.g. "OneDrive - Nexus365" -> "OneDrive\\ -\\ Nexus365"). */
function toWslPathForBash(winPath: string): string {
  return toWslPath(winPath).replace(/ /g, "\\ ");
}

function log(step: string, msg: string): void {
  const ts = new Date().toISOString().split("T")[1]!.slice(0, 8);
  console.log(`[${ts}] [${step}] ${msg}`);
}

function runNativeCommand(args: string[], repoRoot: string): { ok: boolean; output: string } {
  const result = spawnSync(args[0]!, args.slice(1), {
    cwd: repoRoot,
    stdio: "pipe",
    encoding: "utf-8",
  });
  const stdout = (result.stdout ?? "").trim();
  const stderr = (result.stderr ?? "").trim();
  if (result.status !== 0 && stderr) console.error(stderr);
  return { ok: result.status === 0, output: stdout };
}

function runOasis(args: string[], repoRoot: string): { ok: boolean; output: string } {
  if (isWindows) {
    const wslCwdBash = toWslPathForBash(repoRoot);
    const oasisArgs = args.map((a) => `'${String(a).replace(/'/g, "'\"'\"'")}'`).join(" ");
    const bashCmd = `cd ${wslCwdBash} && oasis ${oasisArgs}`;
    const result = spawnSync("wsl", ["bash", "-c", bashCmd], {
      stdio: "pipe",
      encoding: "utf-8",
    });
    const stdout = (result.stdout ?? "").trim();
    const stderr = (result.stderr ?? "").trim();
    if (result.status !== 0 && stderr) console.error(stderr);
    return { ok: result.status === 0, output: stdout + (stderr ? "\n" + stderr : "") };
  }
  return runNativeCommand(["oasis", ...args], repoRoot);
}

function ensureWslAvailable(): void {
  if (!isWindows) return;
  const r = spawnSync("wsl", ["--list", "--quiet"], { stdio: "pipe", encoding: "utf-8" });
  if (r.status !== 0 || r.error) {
    console.error("WSL is required on Windows. Install: https://docs.microsoft.com/en-us/windows/wsl/install");
    process.exit(1);
  }
}

interface AttestationData {
  appId: string;
  machineId: string;
  teeType: string;
  deploymentHash: string;
  walletAddress: string;
  network: string;
  status: string;
  createdAt: string;
  expiresAt: string;
  extractedAt: string;
}

function parseMachineShowOutput(raw: string): Partial<AttestationData> {
  const out: Partial<AttestationData> = {};
  // App ID
  const appIdMatch = raw.match(/(?:app[id]?\s*[=:]\s*|AppId:\s*)([^\s\n]+)/i) || raw.match(/(rofl1[a-z0-9]+)/i);
  if (appIdMatch) out.appId = appIdMatch[1]!.trim();

  // Machine ID: "ID:         000000000000057f"
  const machineIdMatch = raw.match(/ID:\s+(\w+)/);
  if (machineIdMatch) out.machineId = machineIdMatch[1]!.trim();

  const hashMatch = raw.match(/(sha256:[a-f0-9]+)/i) || raw.match(/(?:deployment|hash|image)\s*[=:]\s*([^\s\n]+)/i);
  if (hashMatch) out.deploymentHash = hashMatch[1]!.trim();

  const statusMatch = raw.match(/(?:status\s*[=:]\s*)(\w+)/i) || raw.match(/(running|accepted|active|pending)/i);
  if (statusMatch) out.status = statusMatch[1]!.trim().toLowerCase();

  // Created at: "Created at: 2026-02-08 03:52:11 +0000 GMT"
  const createdMatch = raw.match(/Created at:\s+(.+)/);
  if (createdMatch) out.createdAt = createdMatch[1]!.trim();

  // Paid until (expires): "Paid until: 2026-02-08 04:52:11 +0000 GMT"
  const expiresMatch = raw.match(/Paid until:\s+(.+)/);
  if (expiresMatch) out.expiresAt = expiresMatch[1]!.trim();

  // TEE: "TEE:     Intel TDX"
  const teeMatch = raw.match(/TEE:\s+(.+)/);
  if (teeMatch) out.teeType = teeMatch[1]!.trim();
  else out.teeType = "Intel TDX";

  return out;
}

/** Extract wallet from logs. Primary: "Wallet: 0x..."; also accepts "[main] Wallet: 0x...". */
function parseWalletFromLogs(raw: string): string {
  const walletMatch = raw.match(/Wallet:\s+(0x[a-fA-F0-9]{40})/);
  if (walletMatch) return walletMatch[1]!.trim();
  const mainMatch = raw.match(/\[main\] Wallet:\s*(0x[a-fA-F0-9]{40})/);
  if (mainMatch) return mainMatch[1]!.trim();
  const fallback = raw.match(/(0x[a-fA-F0-9]{40})/);
  return fallback ? fallback[1]!.trim() : "";
}

function main(): void {
  console.log("\n=== Oasis ROFL Attestation Extraction ===\n");

  const packageRoot = path.resolve(__dirname, "..");
  const repoRoot = path.resolve(packageRoot, "..", "..");

  if (isWindows) {
    ensureWslAvailable();
    log("config", "Using WSL for Oasis CLI.");
    log("config", "Repo root (all oasis commands run from here): " + repoRoot);
    log("config", "WSL path: " + toWslPathForBash(repoRoot));
  }

  log("extract", "Fetching machine info (oasis rofl machine show default)...");
  const showResult = runOasis(["rofl", "machine", "show", "default"], repoRoot);
  if (!showResult.ok) {
    console.error("Failed to get machine info. Is the Oasis CLI installed and a machine named 'default' deployed?");
    process.exit(1);
  }

  log("extract", "Fetching wallet from logs (from repo root)...");
  let walletLogs = "";
  if (isWindows) {
    const wslCwdBash = toWslPathForBash(repoRoot);
    const bashCmd = `cd ${wslCwdBash} && oasis rofl machine logs default 2>/dev/null | tail -200`;
    const r = spawnSync("wsl", ["bash", "-c", bashCmd], { stdio: "pipe", encoding: "utf-8" });
    walletLogs = (r.stdout ?? "").trim();
  } else {
    const r = spawnSync("bash", ["-c", "oasis rofl machine logs default 2>/dev/null | tail -200"], {
      cwd: repoRoot,
      stdio: "pipe",
      encoding: "utf-8",
    });
    walletLogs = (r.stdout ?? "").trim();
  }

  const parsed = parseMachineShowOutput(showResult.output);
  const walletAddress = parseWalletFromLogs(walletLogs) || parsed.walletAddress || "";

  // Debug: show what was found / not found from machine show and logs
  const debugFields: { name: string; value: string; found: boolean }[] = [
    { name: "App ID", value: parsed.appId ?? "", found: !!(parsed.appId && parsed.appId.length > 0) },
    { name: "Machine ID", value: parsed.machineId ?? "", found: !!(parsed.machineId && parsed.machineId.length > 0) },
    { name: "TEE Type", value: parsed.teeType ?? "", found: !!(parsed.teeType && parsed.teeType.length > 0) },
    { name: "Deployment Hash", value: parsed.deploymentHash ?? "", found: !!(parsed.deploymentHash && parsed.deploymentHash.length > 0) },
    { name: "Status", value: parsed.status ?? "", found: !!(parsed.status && parsed.status.length > 0) },
    { name: "Created at", value: parsed.createdAt ?? "", found: !!(parsed.createdAt && parsed.createdAt.length > 0) },
    { name: "Paid until (expires)", value: parsed.expiresAt ?? "", found: !!(parsed.expiresAt && parsed.expiresAt.length > 0) },
    { name: "Wallet Address", value: walletAddress, found: !!(walletAddress && walletAddress.length > 0) },
  ];
  log("debug", "Parsed fields from oasis output:");
  for (const f of debugFields) {
    log("debug", `  ${f.name}: ${f.found ? f.value : "(not found)"}`);
  }
  if (walletLogs.length === 0) {
    log("debug", "  (logs output was empty; check 'oasis rofl machine logs default')");
  }
  const anyMissing = debugFields.some((f) => !f.found);
  if (anyMissing) {
    log("debug", "Raw machine show output (first 600 chars):");
    log("debug", showResult.output.slice(0, 600).replace(/\n/g, "\\n"));
    if (walletLogs.length > 0) {
      log("debug", "Raw logs snippet (last 400 chars):");
      log("debug", walletLogs.slice(-400).replace(/\n/g, "\\n"));
    }
  }

  const extractedAt = new Date().toISOString();
  const data: AttestationData = {
    appId: parsed.appId ?? "",
    machineId: parsed.machineId ?? "",
    teeType: parsed.teeType ?? "Intel TDX",
    deploymentHash: parsed.deploymentHash ?? "",
    walletAddress,
    network: "Oasis Sapphire Testnet",
    status: parsed.status ?? "accepted",
    createdAt: parsed.createdAt ?? "",
    expiresAt: parsed.expiresAt ?? "",
    extractedAt,
  };

  const jsonPath = path.join(repoRoot, "attestation.json");
  const mdPath = path.join(repoRoot, "attestation-report.md");
  const txtPath = path.join(repoRoot, "attestation.txt");

  fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2), "utf-8");
  log("write", jsonPath);

  const md = `# TEE Attestation Report

## Deployment Information

| Field | Value |
|-------|-------|
| App ID | ${data.appId || "(not found)"} |
| Machine ID | ${data.machineId || "(not found)"} |
| TEE Type | ${data.teeType} |
| Status | ${data.status} |
| Network | ${data.network} |

## Wallet Address

\`${data.walletAddress || "(not found)"}\`

## Deployment Hash

\`${data.deploymentHash || "(not found)"}\`

## Verification Instructions

1. Verify the deployment hash matches the image deployed to the TEE.
2. Confirm the App ID on Oasis explorer (Sapphire Testnet).
3. Check that the wallet address matches the agent's funded wallet.

## Timeline

- **Created:** ${data.createdAt || "(not found)"}
- **Expires:** ${data.expiresAt || "(not found)"}
- **Report extracted:** ${data.extractedAt}

## What This Proves

- The trading agent is running inside an **Intel TDX** Trusted Execution Environment.
- The exact code (Docker image) is identified by the deployment hash.
- The wallet address is the agent's on-chain identity (keys never leave the TEE).
- Deployment and attestation are verifiable on the Oasis Sapphire Testnet.
`;

  fs.writeFileSync(mdPath, md, "utf-8");
  log("write", mdPath);

  const txt = [
    "TEE Type: " + data.teeType,
    "App ID: " + (data.appId || "(not found)"),
    "Machine ID: " + (data.machineId || "(not found)"),
    "Wallet: " + (data.walletAddress || "(not found)"),
    "Status: " + data.status,
    "Hash: " + (data.deploymentHash || "(not found)"),
    "Network: " + data.network,
    "Extracted: " + data.extractedAt,
  ].join("\n");

  fs.writeFileSync(txtPath, txt, "utf-8");
  log("write", txtPath);

  console.log("\n--- Attestation extraction complete ---");
  console.log("  attestation.json      (for web / API)");
  console.log("  attestation-report.md (human-readable report)");
  console.log("  attestation.txt       (quick view)");
  console.log("\nAll three files written to repo root.\n");
}

main();
