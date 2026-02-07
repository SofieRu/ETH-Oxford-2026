import React from "react";
import { motion } from "framer-motion";
import { Cpu, Key, BarChart3, ArrowRightLeft } from "lucide-react";

const steps = [
  {
    icon: Cpu,
    label: "TEE Boots",
    title: "Encrypted enclave starts",
    desc: "The ROFL container launches inside the Oasis TEE. All memory is encrypted at hardware level.",
    color: "emerald"
  },
  {
    icon: Key,
    label: "Key Generation",
    title: "Private key is born in hardware",
    desc: "The bot derives a unique private key using the TEE's hardware root of trust. No human ever sees it.",
    color: "blue"
  },
  {
    icon: BarChart3,
    label: "Signal Analysis",
    title: "AI reads market signals",
    desc: "Price feeds from oracles are analysed. When ETH meets the trigger condition, the bot prepares a swap.",
    color: "violet"
  },
  {
    icon: ArrowRightLeft,
    label: "Execution",
    title: "Trustless on-chain swap",
    desc: "The TEE signs and submits the transaction to Base Sepolia. ETH → USDC via Uniswap V2, fully autonomous.",
    color: "amber"
  }
];

const colorMap = {
  emerald: { bg: "bg-emerald-500/10", border: "border-emerald-500/20", text: "text-emerald-400", dot: "bg-emerald-400" },
  blue: { bg: "bg-blue-500/10", border: "border-blue-500/20", text: "text-blue-400", dot: "bg-blue-400" },
  violet: { bg: "bg-violet-500/10", border: "border-violet-500/20", text: "text-violet-400", dot: "bg-violet-400" },
  amber: { bg: "bg-amber-500/10", border: "border-amber-500/20", text: "text-amber-400", dot: "bg-amber-400" }
};

const fadeUp = {
  initial: { opacity: 0, y: 30 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-50px" },
  transition: { duration: 0.6 }
};

export default function HowItWorksSection() {
  return (
    <section className="relative py-28 px-4">
      <div className="max-w-5xl mx-auto">
        <motion.div {...fadeUp} className="text-center mb-16">
          <span className="text-xs font-mono tracking-widest text-emerald-400 uppercase">Architecture</span>
          <h2 className="text-3xl sm:text-4xl font-bold text-white mt-3">
            How It Works
          </h2>
          <p className="text-slate-400 mt-3 max-w-xl mx-auto">
            From boot to execution — the entire lifecycle runs inside encrypted hardware.
          </p>
        </motion.div>

        <div className="relative">
          {/* Vertical connector line */}
          <div className="absolute left-6 md:left-1/2 top-0 bottom-0 w-px bg-gradient-to-b from-emerald-500/20 via-blue-500/20 to-amber-500/20 hidden sm:block" />

          <div className="space-y-8 sm:space-y-12">
            {steps.map((step, i) => {
              const c = colorMap[step.color];
              const Icon = step.icon;
              const isEven = i % 2 === 0;
              
              return (
                <motion.div
                  key={i}
                  initial={{ opacity: 0, x: isEven ? -30 : 30 }}
                  whileInView={{ opacity: 1, x: 0 }}
                  viewport={{ once: true, margin: "-50px" }}
                  transition={{ duration: 0.6, delay: i * 0.1 }}
                  className={`relative flex flex-col sm:flex-row items-start sm:items-center gap-6 ${
                    !isEven ? "sm:flex-row-reverse" : ""
                  }`}
                >
                  {/* Step card */}
                  <div className={`flex-1 ${isEven ? "sm:text-right" : "sm:text-left"}`}>
                    <div className={`inline-block rounded-2xl ${c.bg} border ${c.border} p-6 sm:p-8 max-w-md ${
                      isEven ? "sm:ml-auto" : ""
                    }`}>
                      <div className={`inline-flex items-center gap-2 ${c.text} mb-3`}>
                        <span className="text-xs font-mono tracking-wider uppercase">{step.label}</span>
                      </div>
                      <h3 className="text-lg font-semibold text-white mb-2">{step.title}</h3>
                      <p className="text-sm text-slate-400 leading-relaxed">{step.desc}</p>
                    </div>
                  </div>

                  {/* Center dot */}
                  <div className="hidden sm:flex items-center justify-center relative z-10">
                    <div className={`w-12 h-12 rounded-full ${c.bg} border ${c.border} flex items-center justify-center`}>
                      <Icon className={`w-5 h-5 ${c.text}`} />
                    </div>
                  </div>

                  {/* Spacer */}
                  <div className="flex-1 hidden sm:block" />
                </motion.div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}