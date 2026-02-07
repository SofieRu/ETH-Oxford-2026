import React from "react";
import { motion } from "framer-motion";
import { AlertTriangle, ArrowRight, ShieldCheck } from "lucide-react";

const fadeUp = {
  initial: { opacity: 0, y: 30 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-50px" },
  transition: { duration: 0.6 }
};

export default function ProblemSection() {
  return (
    <section className="relative py-28 px-4">
      <div className="max-w-5xl mx-auto">
        <motion.div {...fadeUp} className="text-center mb-16">
          <span className="text-xs font-mono tracking-widest text-amber-400 uppercase">The Problem</span>
          <h2 className="text-3xl sm:text-4xl font-bold text-white mt-3">
            Custodial Trust Is Broken
          </h2>
        </motion.div>

        <div className="grid md:grid-cols-2 gap-6 items-stretch">
          {/* Before */}
          <motion.div
            {...fadeUp}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="relative rounded-2xl border border-red-500/20 bg-red-500/[0.03] p-8 overflow-hidden"
          >
            <div className="absolute top-0 right-0 w-40 h-40 bg-red-500/5 rounded-full blur-[60px]" />
            <div className="relative">
              <div className="inline-flex items-center gap-2 text-red-400 mb-5">
                <AlertTriangle className="w-4 h-4" />
                <span className="text-xs font-mono tracking-wider uppercase">Current Model</span>
              </div>
              <h3 className="text-xl font-semibold text-white mb-4">
                You trust the developer with your private keys
              </h3>
              <div className="space-y-4 text-sm text-slate-400 leading-relaxed">
                <p>
                  Automated trading bots run on <span className="text-slate-300">the developer's server</span>.
                  They hold your private keys in plain memory.
                </p>
                <p>
                  Nothing stops them from extracting those keys, signing unauthorized transactions, 
                  or performing a <span className="text-red-400 font-medium">rug pull</span>.
                </p>
                <div className="mt-6 p-4 rounded-xl bg-black/30 border border-white/5 font-mono text-xs text-slate-500">
                  <span className="text-red-400">// developer's server</span><br/>
                  const userKey = process.env.PRIVATE_KEY<br/>
                  <span className="text-red-400">// ← fully visible, extractable</span>
                </div>
              </div>
            </div>
          </motion.div>

          {/* After */}
          <motion.div
            {...fadeUp}
            transition={{ duration: 0.6, delay: 0.25 }}
            className="relative rounded-2xl border border-emerald-500/20 bg-emerald-500/[0.03] p-8 overflow-hidden"
          >
            <div className="absolute top-0 right-0 w-40 h-40 bg-emerald-500/5 rounded-full blur-[60px]" />
            <div className="relative">
              <div className="inline-flex items-center gap-2 text-emerald-400 mb-5">
                <ShieldCheck className="w-4 h-4" />
                <span className="text-xs font-mono tracking-wider uppercase">TEE Model</span>
              </div>
              <h3 className="text-xl font-semibold text-white mb-4">
                The bot generates its own keys in hardware
              </h3>
              <div className="space-y-4 text-sm text-slate-400 leading-relaxed">
                <p>
                  Inside a <span className="text-slate-300">Trusted Execution Environment</span>,
                  an encrypted enclave in the CPU, the bot creates and holds its own private key.
                </p>
                <p>
                  The developer <span className="text-emerald-400 font-medium">cannot see, extract, or override</span> the 
                  key. Trust shifts from people to verifiable code.
                </p>
                <div className="mt-6 p-4 rounded-xl bg-black/30 border border-white/5 font-mono text-xs text-slate-500">
                  <span className="text-emerald-400">// inside TEE enclave</span><br/>
                  const key = tee.deriveKey()<br/>
                  <span className="text-emerald-400">// ← hardware-sealed, unextractable</span>
                </div>
              </div>
            </div>
          </motion.div>
        </div>

        <motion.div
          {...fadeUp}
          transition={{ duration: 0.6, delay: 0.4 }}
          className="flex justify-center mt-8"
        >
          <div className="inline-flex items-center gap-3 px-5 py-2.5 rounded-full bg-white/5 border border-white/10 text-sm text-slate-400">
            Trust the developer
            <ArrowRight className="w-4 h-4 text-emerald-400" />
            <span className="text-white font-medium">Trust the code + TEE</span>
          </div>
        </motion.div>
      </div>
    </section>
  );
}