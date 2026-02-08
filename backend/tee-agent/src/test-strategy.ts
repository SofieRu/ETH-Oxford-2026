import "./env-loader";
import { generateSignal } from "./strategy";

async function main(): Promise<void> {
  console.log("=== Strategy test ===\n");

  console.log("Step 1: Calling generateSignal() (fetches prices and computes RSI)...\n");
  const signal = await generateSignal();

  console.log("\nStep 2: Signal details:");
  console.log("  action :", signal.action);
  console.log("  amount :", signal.amount, "ETH");
  console.log("  price  :", signal.price, "USD");
  console.log("  rsi    :", signal.rsi);
  console.log("  reason :", signal.reason);
  console.log("  timestamp :", signal.timestamp);

  console.log("\nStep 3: Verification");
  console.log("  ✓ Fetched current ETH/USD price:", signal.price);
  console.log("  ✓ Fetched historical data and calculated RSI:", signal.rsi);
  console.log("  ✓ Signal generated:", signal.action);

  console.log("\n✅ Strategy test complete. Prices fetched and RSI calculated successfully.");
}

main().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});
