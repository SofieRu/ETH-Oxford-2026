import React from "react";
import { motion } from "framer-motion";

const stack = [
  {
    name: "Oasis ROFL",
    role: "TEE Infrastructure",
    desc: "Provides the trusted execution environment and remote attestation layer.",
    mono: true
  },
  {
    name: "Eliza / Node.js",
    role: "Trading Logic",
    desc: "TypeScript runtime that handles price analysis and swap execution.",
    mono: true
  },
  {
    name: "Base Sepolia",
    role: "Target Chain",
    desc: "Ethereum L2 testnet — cheap, fast, and EVM-compatible.",
    mono: true
  },
  {
    name: "Uniswap V2",
    role: "DEX Protocol",
    desc: "Decentralized exchange protocol used for the ETH → USDC swap.",
    mono: true
  }
];

const fadeUp = {
  initial: { opacity: 0, y: 30 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-50px" },
  transition: { duration: 0.6 }
};

export default function TechStackSection() {
  return (
    <section className="relative py-28 px-4">
      <div className="max-w-4xl mx-auto">
        <motion.div {...fadeUp} className="text-center mb-16">
          <span className="text-xs font-mono tracking-widest text-emerald-400 uppercase">Stack</span>
          <h2 className="text-3xl sm:text-4xl font-bold text-white mt-3">
            Technical Foundation
          </h2>
        </motion.div>

        <div className="grid sm:grid-cols-2 gap-5">
          {stack.map((item, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ duration: 0.5, delay: i * 0.1 }}
              className="rounded-xl border border-white/5 bg-white/[0.02] p-6 hover:bg-white/[0.04] hover:border-white/10 transition-all duration-300"
            >
              <div className="flex items-baseline gap-3 mb-2">
                <h3 className="text-white font-semibold font-mono">{item.name}</h3>
                <span className="text-[10px] font-mono tracking-widest text-slate-500 uppercase">{item.role}</span>
              </div>
              <p className="text-sm text-slate-400 leading-relaxed">{item.desc}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}