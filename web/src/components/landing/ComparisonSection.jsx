import React from "react";
import { motion } from "framer-motion";
import { Check, X, Minus } from "lucide-react";

const solutions = [
  {
    name: "Multisig Committees",
    desc: "Group of humans vote to move money",
    autonomy: false,
    speed: false,
    trust: true,
    intelligence: false
  },
  {
    name: "Smart Contracts",
    desc: "On-chain logic, deterministic execution",
    autonomy: true,
    speed: true,
    trust: true,
    intelligence: false
  },
  {
    name: "Custodial Bots",
    desc: "AI on a normal server, dev holds keys",
    autonomy: true,
    speed: true,
    trust: false,
    intelligence: true
  },
  {
    name: "TEE + AI Bot",
    desc: "AI in encrypted hardware, self-custodial keys",
    autonomy: true,
    speed: "partial",
    trust: true,
    intelligence: true,
    highlight: true
  }
];

const criteria = [
  { key: "autonomy", label: "Autonomous" },
  { key: "speed", label: "Fast Execution" },
  { key: "trust", label: "Trustless" },
  { key: "intelligence", label: "AI-Capable" }
];

function StatusIcon({ value }) {
  if (value === true) return <Check className="w-4 h-4 text-emerald-400" />;
  if (value === false) return <X className="w-4 h-4 text-red-400/60" />;
  return <Minus className="w-4 h-4 text-amber-400" />;
}

const fadeUp = {
  initial: { opacity: 0, y: 30 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-50px" },
  transition: { duration: 0.6 }
};

export default function ComparisonSection() {
  return (
    <section className="relative py-28 px-4">
      <div className="max-w-4xl mx-auto">
        <motion.div {...fadeUp} className="text-center mb-16">
          <span className="text-xs font-mono tracking-widest text-blue-400 uppercase">Comparison</span>
          <h2 className="text-3xl sm:text-4xl font-bold text-white mt-3">
            Current Solutions Fall Short
          </h2>
        </motion.div>

        {/* Mobile cards */}
        <div className="sm:hidden space-y-4">
          {solutions.map((sol, i) => (
            <motion.div
              key={i}
              {...fadeUp}
              transition={{ duration: 0.5, delay: i * 0.1 }}
              className={`rounded-xl p-5 border ${
                sol.highlight
                  ? "border-emerald-500/30 bg-emerald-500/[0.04]"
                  : "border-white/5 bg-white/[0.02]"
              }`}
            >
              <div className="flex items-center justify-between mb-1">
                <h3 className={`font-semibold ${sol.highlight ? "text-emerald-400" : "text-white"}`}>
                  {sol.name}
                </h3>
                {sol.highlight && (
                  <span className="text-[10px] font-mono tracking-wider text-emerald-400 bg-emerald-400/10 px-2 py-0.5 rounded-full">
                    OURS
                  </span>
                )}
              </div>
              <p className="text-xs text-slate-500 mb-4">{sol.desc}</p>
              <div className="grid grid-cols-2 gap-3">
                {criteria.map(c => (
                  <div key={c.key} className="flex items-center gap-2">
                    <StatusIcon value={sol[c.key]} />
                    <span className="text-xs text-slate-400">{c.label}</span>
                  </div>
                ))}
              </div>
            </motion.div>
          ))}
        </div>

        {/* Desktop table */}
        <motion.div {...fadeUp} className="hidden sm:block">
          <div className="rounded-2xl border border-white/5 overflow-hidden bg-white/[0.01] backdrop-blur-sm">
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/5">
                  <th className="text-left p-5 text-sm font-medium text-slate-500">Solution</th>
                  {criteria.map(c => (
                    <th key={c.key} className="p-5 text-center text-sm font-medium text-slate-500">
                      {c.label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {solutions.map((sol, i) => (
                  <tr
                    key={i}
                    className={`border-b border-white/5 last:border-0 transition-colors ${
                      sol.highlight
                        ? "bg-emerald-500/[0.04]"
                        : "hover:bg-white/[0.02]"
                    }`}
                  >
                    <td className="p-5">
                      <div className="flex items-center gap-3">
                        <div>
                          <span className={`text-sm font-semibold ${sol.highlight ? "text-emerald-400" : "text-white"}`}>
                            {sol.name}
                          </span>
                          {sol.highlight && (
                            <span className="ml-2 text-[10px] font-mono tracking-wider text-emerald-400 bg-emerald-400/10 px-2 py-0.5 rounded-full">
                              OURS
                            </span>
                          )}
                          <p className="text-xs text-slate-500 mt-0.5">{sol.desc}</p>
                        </div>
                      </div>
                    </td>
                    {criteria.map(c => (
                      <td key={c.key} className="p-5 text-center">
                        <div className="flex justify-center">
                          <StatusIcon value={sol[c.key]} />
                        </div>
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </motion.div>
      </div>
    </section>
  );
}