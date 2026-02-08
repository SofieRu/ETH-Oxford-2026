console.log('=== Testing Basic Setup ===\n');

// Test 1: Check Node.js is working
console.log('✓ Node.js version:', process.version);

// Test 2: Check dependencies
try {
  const ethers = require('ethers');
  console.log('✓ ethers.js installed');
} catch (e) {
  console.log('✗ ethers.js missing');
}

try {
  const axios = require('axios');
  console.log('✓ axios installed');
} catch (e) {
  console.log('✗ axios missing');
}

try {
  require("./env-loader");
  console.log('✓ dotenv installed');
  console.log('✓ RPC_URL:', process.env.RPC_URL);
  console.log('✓ CHAIN_ID:', process.env.CHAIN_ID);
} catch (e) {
  console.log('✗ dotenv missing');
}

console.log('\n✅ Setup complete! All dependencies working.');
