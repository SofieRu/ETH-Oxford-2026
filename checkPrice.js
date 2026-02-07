import "dotenv/config";
import axios from "axios";

async function checkPrice() {
	const url = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd&include_24hr_change=true";

	const response = await axios.get(url);
	const price = response.data.ethereum.usd;
	const change = response.data.ethereum.usd_24h_change;

	console.log("=== ETH Price ===");
	console.log(`Price: $${price}`);
	console.log(`24h Change: ${change.toFixed(2)}%`);

	return { price, change };
}

checkPrice();