import "./env-loader";
import { ethers } from "ethers";
import { initWallet, getBalance } from "./wallet";
import { generateSignal } from "./strategy";
import { loadPolicy, checkPolicy } from "./policy";
import { buildSwapTransaction } from "./trader";

async function main(): Promise<void> {
  console.log("=== Test: one cycle of trading flow (no broadcast) ===\n");

  const rpcUrl = process.env.RPC_URL;
  if (!rpcUrl) {
    console.error("RPC_URL is not set in .env");
    process.exit(1);
  }

  // --- Initialize wallet ---
  console.log("Initializing wallet...");
  const wallet = await initWallet();
  console.log("Wallet loaded:", wallet.address);
  console.log();

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  try {
    const balance = await getBalance(wallet, provider);
    console.log("Balance:", ethers.formatEther(balance), "ETH");
  } catch (e) {
    console.log("Balance: (RPC unreachable — skipped)");
  }
  console.log();

  const policy = loadPolicy();
  if (policy.emergencyStop) {
    console.log("Emergency stop is ON — policy would block all trades.");
  }
  console.log();

  // --- Generate signal ---
  let signal;
  try {
    console.log("Generating signal...");
    signal = await generateSignal();
    console.log("Signal generated:", signal.action);
    console.log("  amount :", signal.amount, "ETH");
    console.log("  price  :", signal.price);
    console.log("  rsi    :", signal.rsi);
    console.log("  reason :", signal.reason);
  } catch (err) {
    console.error("Signal generation failed:", err instanceof Error ? err.message : String(err));
    process.exit(1);
  }
  console.log();

  // --- Check policy ---
  console.log("Checking policy...");
  const check = checkPolicy(signal, policy);
  if (check.allowed) {
    console.log("Policy check: PASS");
    if (check.reason) console.log("  reason:", check.reason);
  } else {
    console.log("Policy check: FAIL");
    console.log("  reason:", check.reason ?? "unknown");
    if (check.details) console.log("  details:", JSON.stringify(check.details));
  }
  console.log();

  // --- Build transaction (don't broadcast) ---
  if (signal.action === "HOLD") {
    console.log("Transaction built: (none — HOLD, no trade)");
  } else if (!check.allowed) {
    console.log("Transaction built: (skipped — policy rejected)");
  } else {
    console.log("Building swap transaction (not broadcasting)...");
    try {
      const tx = await buildSwapTransaction(signal, wallet, provider);
      console.log("Transaction built: OK");
      console.log("  to       :", tx.to);
      console.log("  value    :", tx.value?.toString() ?? "0", "wei");
      console.log("  gasLimit :", tx.gasLimit?.toString() ?? "(none)");
      console.log("  gasPrice :", tx.gasPrice?.toString() ?? "(none)");
      if (tx.maxFeePerGas != null) {
        console.log("  maxFeePerGas :", tx.maxFeePerGas.toString());
      }
      console.log("  data     :", typeof tx.data === "string" ? tx.data.slice(0, 66) + "..." : "(none)");
    } catch (err) {
      console.error("Transaction build failed:", err instanceof Error ? err.message : String(err));
    }
  }
  console.log();

  console.log("Would execute in production (swap not sent in this test).");
  console.log("\n✅ One-cycle test complete. Exiting.");
  provider.destroy();
}

main().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});
