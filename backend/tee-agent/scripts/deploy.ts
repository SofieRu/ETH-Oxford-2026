/**
 * Oasis ROFL TEE deployment automation.
 * Run from backend/tee-agent: npm run deploy
 *
 * Steps: Docker build → push to Docker Hub → oasis rofl build → update → deploy.
 */

import path from "path";
import { spawnSync } from "child_process";
import * as readline from "readline";

const DEFAULT_ACCOUNT = "my_wallet";
const IMAGE_NAME = "trading-bot";
const IMAGE_TAG = "latest";

const isWindows = process.platform === "win32";

/** Convert Windows path to WSL path (e.g. C:\repo -> /mnt/c/repo). */
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

function ensureWslAvailable(): void {
  if (!isWindows) return;
  const r = spawnSync("wsl", ["--list", "--quiet"], { stdio: "pipe", encoding: "utf-8" });
  if (r.status !== 0 || r.error) {
    console.error("WSL is required for Oasis CLI on Windows but could not be found.");
    console.error("Install WSL: https://docs.microsoft.com/en-us/windows/wsl/install");
    console.error("Then install the Oasis CLI inside your WSL distribution.");
    process.exit(1);
  }
  log("config", "Using WSL for Oasis CLI commands.");
}

function log(step: string, msg: string): void {
  const ts = new Date().toISOString().split("T")[1]!.slice(0, 8);
  console.log(`[${ts}] [${step}] ${msg}`);
}

function prompt(question: string, defaultValue?: string): Promise<string> {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const def = defaultValue ? ` (${defaultValue})` : "";
  return new Promise((resolve) => {
    rl.question(`${question}${def}: `, (answer) => {
      rl.close();
      resolve((answer || defaultValue || "").trim());
    });
  });
}

function run(
  step: string,
  command: string,
  args: string[],
  options: { cwd: string; env?: NodeJS.ProcessEnv } = { cwd: process.cwd() }
): { ok: boolean; output: string } {
  log(step, `Running: ${command} ${args.join(" ")}`);
  const result = spawnSync(command, args, {
    cwd: options.cwd,
    env: options.env ?? process.env,
    stdio: ["inherit", "pipe", "pipe"],
    shell: process.platform === "win32",
  });
  const stdout = (result.stdout?.toString() ?? "").trim();
  const stderr = (result.stderr?.toString() ?? "").trim();
  if (result.status !== 0) {
    if (stderr) console.error(stderr);
    return { ok: false, output: stdout + "\n" + stderr };
  }
  return { ok: true, output: stdout };
}

function runInteractive(
  step: string,
  command: string,
  args: string[],
  options: { cwd: string } = { cwd: process.cwd() }
): { ok: boolean; output: string } {
  log(step, `Running: ${command} ${args.join(" ")}`);
  const result = spawnSync(command, args, {
    cwd: options.cwd,
    stdio: "inherit",
    shell: process.platform === "win32",
  });
  return { ok: result.status === 0, output: "" };
}

/** Run Oasis CLI (via WSL on Windows, native on Linux). */
function runOasis(
  step: string,
  args: string[],
  repoRoot: string,
  options: { stdio: "pipe" | "inherit" } = { stdio: "pipe" }
): { ok: boolean; output: string } {
  const command = isWindows ? "wsl" : "oasis";
  const cmdArgs = isWindows ? ["oasis", ...args] : args;
  const displayCmd = isWindows ? `wsl oasis ${args.join(" ")}` : `oasis ${args.join(" ")}`;
  log(step, `Running: ${displayCmd}`);

  if (isWindows) {
    const wslCwd = toWslPath(repoRoot);
    const escapedCwd = wslCwd.replace(/'/g, "'\"'\"'");
    const bashCmd = `cd '${escapedCwd}' && oasis ${args.map((a) => `'${a.replace(/'/g, "'\"'\"'")}'`).join(" ")}`;
    const result = spawnSync("wsl", ["bash", "-c", bashCmd], {
      stdio: options.stdio,
      encoding: options.stdio === "pipe" ? "utf-8" : undefined,
    });
    const stdout = options.stdio === "pipe" && result.stdout ? String(result.stdout).trim() : "";
    const stderr = options.stdio === "pipe" && result.stderr ? String(result.stderr).trim() : "";
    if (result.status !== 0 && stderr) console.error(stderr);
    return { ok: result.status === 0, output: stdout + (stderr ? "\n" + stderr : "") };
  }

  const result = spawnSync(command, cmdArgs, {
    cwd: repoRoot,
    stdio: options.stdio,
    encoding: options.stdio === "pipe" ? "utf-8" : undefined,
  });
  const stdout = options.stdio === "pipe" && result.stdout ? String(result.stdout).trim() : "";
  const stderr = options.stdio === "pipe" && result.stderr ? String(result.stderr).trim() : "";
  if (result.status !== 0 && stderr) console.error(stderr);
  return { ok: result.status === 0, output: stdout + (stderr ? "\n" + stderr : "") };
}

function extractAppId(output: string): string | null {
  const match = output.match(/app[id]?\s*[=:]\s*([^\s\n]+)/i) || output.match(/(rofl1[a-z0-9]+)/i);
  return match ? match[1]!.trim() : null;
}

function extractWallet(output: string): string | null {
  const match = output.match(/wallet\s*[=:]\s*(0x[a-fA-F0-9]{40})/i) || output.match(/(0x[a-fA-F0-9]{40})/);
  return match ? match[1]!.trim() : null;
}

async function main(): Promise<void> {
  console.log("\n=== Oasis ROFL TEE Deployment ===\n");

  const packageRoot = path.resolve(__dirname, "..");
  const repoRoot = path.resolve(packageRoot, "..", "..");

  if (isWindows) ensureWslAvailable();

  let dockerUser = process.env.DOCKER_USERNAME ?? process.env.DOCKER_USER ?? "";
  if (!dockerUser) {
    dockerUser = await prompt("Docker Hub username");
    if (!dockerUser) {
      console.error("Docker Hub username is required. Set DOCKER_USERNAME or run again and enter it.");
      process.exit(1);
    }
  }
  const imageRef = `${dockerUser}/${IMAGE_NAME}:${IMAGE_TAG}`;
  log("config", `Image: ${imageRef}`);
  log("config", `Repo root: ${repoRoot}`);
  log("config", `Oasis account: ${process.env.OASIS_ACCOUNT ?? DEFAULT_ACCOUNT}`);

  const account = process.env.OASIS_ACCOUNT ?? DEFAULT_ACCOUNT;

  if (!process.env.DOCKER_PASSWORD && process.platform !== "win32") {
    console.log("\nTip: Set DOCKER_PASSWORD to avoid typing your Docker Hub password.\n");
  }

  // 1. Docker build
  log("docker", "Building image...");
  const build = run("docker", "docker", ["build", "-t", imageRef, "."], { cwd: repoRoot });
  if (!build.ok) {
    console.error("\nDocker build failed.");
    process.exit(1);
  }
  log("docker", "Build succeeded.");

  // 2. Docker push
  log("docker", "Pushing to Docker Hub...");
  const push = runInteractive("docker", "docker", ["push", imageRef], { cwd: repoRoot });
  if (!push.ok) {
    console.error("\nDocker push failed. Check DOCKER_USERNAME and login (docker login).");
    process.exit(1);
  }
  log("docker", "Push succeeded.");

  // 3. Oasis ROFL build
  log("rofl", "Building ROFL bundle...");
  const roflBuild = runOasis("rofl", ["rofl", "build", "--force"], repoRoot, { stdio: "pipe" });
  if (!roflBuild.ok) {
    console.error("\nOasis ROFL build failed.");
    process.exit(1);
  }
  log("rofl", "ROFL build succeeded.");

  // 4. Oasis ROFL update (interactive: may prompt for passphrase)
  log("rofl", "Updating on-chain configuration...");
  const roflUpdate = runOasis("rofl", ["rofl", "update", "--account", account], repoRoot, { stdio: "inherit" });
  if (!roflUpdate.ok) {
    console.error("\nOasis ROFL update failed.");
    process.exit(1);
  }
  log("rofl", "Update succeeded.");

  // 5. Oasis ROFL deploy (interactive so user can enter passphrase if prompted)
  console.log("\nYou may be prompted for your Oasis wallet passphrase.\n");
  log("rofl", "Deploying to TEE...");
  const roflDeploy = runOasis("rofl", ["rofl", "deploy", "--account", account, "--force"], repoRoot, { stdio: "inherit" });
  if (!roflDeploy.ok) {
    console.error("\nOasis ROFL deploy failed.");
    process.exit(1);
  }

  log("rofl", "Deploy succeeded.");

  const deployOutput = roflDeploy.output;
  const appId = extractAppId(deployOutput);
  const wallet = extractWallet(deployOutput);

  console.log("\n--- Deployment complete ---");
  console.log("Image:", imageRef);
  console.log("Account:", account);
  if (appId) console.log("App ID:", appId);
  if (wallet) console.log("Wallet:", wallet);
  if (!appId && !wallet) console.log("(Check oasis CLI output above for App ID and wallet address.)");
  console.log("\n");
}

main().catch((err) => {
  console.error("Deployment error:", err);
  process.exit(1);
});
