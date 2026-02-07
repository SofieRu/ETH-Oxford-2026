import "dotenv/config";
import { ethers } from "ethers";
import { initWallet, getBalance } from "./wallet";
import { buildSwapTransaction } from "./trader";
import type { TradingSignal } from "./strategy";

async function main(): Promise<void> {
  console.log("=== Trader test (build only, no broadcast) ===\n");

  console.log("Initializing wallet...");
  const wallet = await initWallet();
  console.log("Wallet address:", wallet.address);
  console.log();

  const rpcUrl = process.env.RPC_URL ?? "https://sepolia.base.org";
  console.log("Creating provider (RPC):", rpcUrl);
  const provider = new ethers.JsonRpcProvider(rpcUrl);

  console.log("Checking wallet balance...");
  try {
    const balance = await getBalance(wallet, provider);
    console.log("Balance:", ethers.formatEther(balance), "ETH");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log("(RPC unreachable —", msg.slice(0, 60) + (msg.length > 60 ? "..." : ""), ")");
    console.log("Skipping balance check; building transaction with fallback gas if needed.");
  }
  console.log();

  const mockSignal: TradingSignal = {
    action: "BUY",
    amount: 0.01,
    price: 3500,
    rsi: 45,
    reason: "test",
    timestamp: Math.floor(Date.now() / 1000),
  };
  console.log("Mock BUY signal: 0.01 ETH @ $3500 (test amount)");
  console.log();

  console.log("Building swap transaction...");
  const tx = await buildSwapTransaction(mockSignal, wallet, provider);

  console.log("\n--- Transaction details ---");
  console.log("  to       :", tx.to);
  console.log("  value    :", tx.value?.toString() ?? "0", "wei (", tx.value ? ethers.formatEther(tx.value) : "0", "ETH)");
  console.log("  data     :", typeof tx.data === "string" ? tx.data.slice(0, 66) + "..." : "(none)");
  console.log("  gasLimit :", tx.gasLimit?.toString() ?? "(none)");
  console.log("  gasPrice :", tx.gasPrice?.toString() ?? "(none)");
  if (tx.maxFeePerGas != null) {
    console.log("  maxFeePerGas         :", tx.maxFeePerGas.toString());
    console.log("  maxPriorityFeePerGas :", tx.maxPriorityFeePerGas?.toString() ?? "(none)");
  }
  console.log();

  console.log("Transaction ready to broadcast (not sending in test)");
  console.log("In production, this would execute on your configured network (e.g. Ethereum Sepolia or Base Sepolia).");
  console.log("\n✅ Trader test complete.");

  provider.destroy();
}

main().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});
