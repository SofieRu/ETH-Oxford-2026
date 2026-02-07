import React from "react";
import { motion } from "framer-motion";
import { Terminal, Code2, Rocket } from "lucide-react";

const phases = [
  {
    icon: Terminal,
    hours: "Hour 0 – 4",
    title: '"Hello TEE"',
    color: "emerald",
    tasks: [
      "Clone the oasis-rofl-starter (TypeScript)",
      'Run the "Key Generation" example locally',
      "Deploy to Oasis Testnet"
    ],
    win: "You see a public address in the logs that you (the dev) did not generate manually."
  },
  {
    icon: Code2,
    hours: "Hour 4 – 12",
    title: "The Trader Logic",
    color: "blue",
    tasks: [
      "Write a Node.js script with a fresh wallet",
      "Fetch ETH price from CoinGecko API",
      "if (price > X) → swap on Uniswap V2",
      "Test on Base Sepolia"
    ],
    win: "The script works on your laptop — swaps ETH to USDC when the condition triggers."
  },
  {
    icon: Rocket,
    hours: "Hour 12 – 18",
    title: "The Lift & Shift",
    color: "violet",
    tasks: [
      "Move script into the ROFL container",
      "Replace ethers.Wallet.createRandom() with TEE-derived key",
      "Deploy to Oasis Testnet"
    ],
    win: "The TEE runs your trading logic with a hardware-secured key."
  }
];

const colorMap = {
  emerald: {
    bg: "bg-emerald-500/10", border: "border-emerald-500/20", text: "text-emerald-400",
    dot: "bg-emerald-400", dotGlow: "bg-emerald-400/20", badge: "bg-emerald-400/10 text-emerald-400"
  },
  blue: {
    bg: "bg-blue-500/10", border: "border-blue-500/20", text: "text-blue-400",
    dot: "bg-blue-400", dotGlow: "bg-blue-400/20", badge: "bg-blue-400/10 text-blue-400"
  },
  violet: {
    bg: "bg-violet-500/10", border: "border-violet-500/20", text: "text-violet-400",
    dot: "bg-violet-400", dotGlow: "bg-violet-400/20", badge: "bg-violet-400/10 text-violet-400"
  }
};

const fadeUp = {
  initial: { opacity: 0, y: 30 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-50px" },
  transition: { duration: 0.6 }
};

export default function RoadmapSection() {
  return (
    <section className="relative py-28 px-4">
      <div className="max-w-5xl mx-auto">
        <motion.div {...fadeUp} className="text-center mb-16">
          <span className="text-xs font-mono tracking-widest text-violet-400 uppercase">Build Plan</span>
          <h2 className="text-3xl sm:text-4xl font-bold text-white mt-3">
            18-Hour Roadmap
          </h2>
          <p className="text-slate-400 mt-3 max-w-lg mx-auto">
            From zero to a TEE-secured autonomous trader on Base Sepolia.
          </p>
        </motion.div>

        <div className="grid md:grid-cols-3 gap-6">
          {phases.map((phase, i) => {
            const c = colorMap[phase.color];
            const Icon = phase.icon;

            return (
              <motion.div
                key={i}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ duration: 0.6, delay: i * 0.15 }}
                className={`relative rounded-2xl border ${c.border} ${c.bg} p-7 flex flex-col`}
              >
                <div className="flex items-center gap-3 mb-5">
                  <div className={`w-10 h-10 rounded-xl ${c.bg} border ${c.border} flex items-center justify-center`}>
                    <Icon className={`w-5 h-5 ${c.text}`} />
                  </div>
                  <div>
                    <span className={`text-xs font-mono ${c.text}`}>{phase.hours}</span>
                    <h3 className="text-white font-semibold text-lg leading-tight">{phase.title}</h3>
                  </div>
                </div>

                <ul className="space-y-3 flex-1 mb-6">
                  {phase.tasks.map((task, j) => (
                    <li key={j} className="flex items-start gap-2.5 text-sm text-slate-400">
                      <div className={`w-1.5 h-1.5 rounded-full ${c.dot} mt-1.5 flex-shrink-0`} />
                      <span>{task}</span>
                    </li>
                  ))}
                </ul>

                <div className="rounded-xl bg-black/20 border border-white/5 p-4">
                  <span className="text-[10px] font-mono tracking-widest text-slate-500 uppercase">Win Condition</span>
                  <p className="text-xs text-slate-300 mt-1.5 leading-relaxed">{phase.win}</p>
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}