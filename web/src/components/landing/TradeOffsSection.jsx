import React from "react";
import { motion } from "framer-motion";
import { TrendingUp, AlertCircle } from "lucide-react";

const strengths = [
  "TEEs use well-established hardware (Intel SGX / ARM TrustZone)",
  "Remote attestation proves code integrity before you fund the wallet",
  "Automation that cannot be easily overridden or tampered with",
  "Creates auditable, verifiable AI behavior on-chain",
  "Trust shifts from people to cryptographic proof"
];

const limitations = [
  "Must trust oracle feeds for real-world price data",
  "TEEs are not bulletproof — side-channel attacks have occurred",
  "Not suitable for high-frequency trading (TEE latency)",
  "TEE does not output error logs — debugging is harder",
  "AI logic must be carefully audited — bad code = bad trades"
];

const fadeUp = {
  initial: { opacity: 0, y: 30 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-50px" },
  transition: { duration: 0.6 }
};

export default function TradeoffsSection() {
  return (
    <section className="relative py-28 px-4">
      <div className="max-w-5xl mx-auto">
        <motion.div {...fadeUp} className="text-center mb-16">
          <span className="text-xs font-mono tracking-widest text-slate-500 uppercase">Honest Assessment</span>
          <h2 className="text-3xl sm:text-4xl font-bold text-white mt-3">
            Strengths & Limitations
          </h2>
          <p className="text-slate-400 mt-3 max-w-lg mx-auto">
            This approach is a significant improvement — but it's not magic. Here's the full picture.
          </p>
        </motion.div>

        <div className="grid md:grid-cols-2 gap-6">
          {/* Strengths */}
          <motion.div
            {...fadeUp}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="rounded-2xl border border-emerald-500/15 bg-emerald-500/[0.02] p-8"
          >
            <div className="flex items-center gap-2 mb-6">
              <TrendingUp className="w-5 h-5 text-emerald-400" />
              <h3 className="text-lg font-semibold text-emerald-400">Strengths</h3>
            </div>
            <ul className="space-y-4">
              {strengths.map((item, i) => (
                <li key={i} className="flex items-start gap-3">
                  <div className="w-5 h-5 rounded-full bg-emerald-400/10 flex items-center justify-center flex-shrink-0 mt-0.5">
                    <div className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                  </div>
                  <span className="text-sm text-slate-300 leading-relaxed">{item}</span>
                </li>
              ))}
            </ul>
          </motion.div>

          {/* Limitations */}
          <motion.div
            {...fadeUp}
            transition={{ duration: 0.6, delay: 0.25 }}
            className="rounded-2xl border border-amber-500/15 bg-amber-500/[0.02] p-8"
          >
            <div className="flex items-center gap-2 mb-6">
              <AlertCircle className="w-5 h-5 text-amber-400" />
              <h3 className="text-lg font-semibold text-amber-400">Limitations</h3>
            </div>
            <ul className="space-y-4">
              {limitations.map((item, i) => (
                <li key={i} className="flex items-start gap-3">
                  <div className="w-5 h-5 rounded-full bg-amber-400/10 flex items-center justify-center flex-shrink-0 mt-0.5">
                    <div className="w-1.5 h-1.5 rounded-full bg-amber-400" />
                  </div>
                  <span className="text-sm text-slate-300 leading-relaxed">{item}</span>
                </li>
              ))}
            </ul>
          </motion.div>
        </div>
      </div>
    </section>
  );
}