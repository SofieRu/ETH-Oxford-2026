import "dotenv/config";
import * as fs from "fs";
import * as path from "path";
import { initWallet, loadWallet, getAddress } from "./wallet";

const DEFAULT_WALLET_FILE = "wallet.enc";

function getWalletPath(): string {
  const file = process.env.WALLET_KEY_FILE ?? DEFAULT_WALLET_FILE;
  return path.isAbsolute(file) ? file : path.join(process.cwd(), file);
}

async function main(): Promise<void> {
  console.log("=== Wallet test ===\n");

  console.log("Step 1: Calling initWallet() to generate or load a wallet...");
  const wallet = await initWallet();
  console.log("initWallet() completed.\n");

  console.log("Step 2: Printing wallet address...");
  const address = getAddress(wallet);
  console.log("Wallet address:", address);
  console.log();

  console.log("Step 3: Checking if the sealed key file was created...");
  const walletPath = getWalletPath();
  const exists = fs.existsSync(walletPath);
  console.log("Wallet file path:", walletPath);
  console.log("File exists:", exists ? "yes" : "no");
  if (!exists) {
    console.log("Expected sealed key file was not found.");
    process.exit(1);
  }
  console.log();

  console.log("Step 4: Loading the wallet again to verify same address...");
  const wallet2 = loadWallet();
  const address2 = getAddress(wallet2);
  console.log("Loaded wallet address:", address2);
  const match = address === address2;
  console.log("Addresses match:", match ? "yes" : "no");
  if (!match) {
    console.log("Error: loaded wallet has a different address.");
    process.exit(1);
  }
  console.log();

  console.log("✅ All wallet test steps passed.");
}

main().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});
