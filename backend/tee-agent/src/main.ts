import "dotenv/config";

function main(): void {
  console.log("Sovereign AI TEE agent started");
  const rpcUrl = process.env.RPC_URL ?? "not set";
  const chainId = process.env.CHAIN_ID ?? "not set";
  console.log(`RPC_URL: ${rpcUrl}, CHAIN_ID: ${chainId}`);
}

main();
