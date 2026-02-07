import React from "react";
import { motion } from "framer-motion";
import { Eye, BarChart3, Landmark } from "lucide-react";

const audiences = [
  {
    icon: Eye,
    title: "Crypto Skeptics",
    desc: "People who distrust centralized AI platforms but still want automation. TEEs let you verify, not just trust.",
    color: "blue"
  },
  {
    icon: BarChart3,
    title: "Algorithmic Traders",
    desc: "Traders who want autonomous execution without handing their private keys to a third party.",
    color: "emerald"
  },
  {
    icon: Landmark,
    title: "DAOs & Treasuries",
    desc: "Organizations that need autonomous treasury management without trusting any single individual.",
    color: "violet"
  }
];

const colorMap = {
  blue: { bg: "bg-blue-500/10", border: "border-blue-500/20", text: "text-blue-400" },
  emerald: { bg: "bg-emerald-500/10", border: "border-emerald-500/20", text: "text-emerald-400" },
  violet: { bg: "bg-violet-500/10", border: "border-violet-500/20", text: "text-violet-400" }
};

const fadeUp = {
  initial: { opacity: 0, y: 30 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-50px" },
  transition: { duration: 0.6 }
};

export default function AudienceSection() {
  return (
    <section className="relative py-28 px-4">
      <div className="max-w-4xl mx-auto">
        <motion.div {...fadeUp} className="text-center mb-16">
          <span className="text-xs font-mono tracking-widest text-blue-400 uppercase">Who Benefits</span>
          <h2 className="text-3xl sm:text-4xl font-bold text-white mt-3">
            Built for the Trust-Minimized
          </h2>
        </motion.div>

        <div className="grid sm:grid-cols-3 gap-6">
          {audiences.map((a, i) => {
            const c = colorMap[a.color];
            const Icon = a.icon;

            return (
              <motion.div
                key={i}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ duration: 0.6, delay: i * 0.12 }}
                className={`rounded-2xl border ${c.border} ${c.bg} p-7 text-center`}
              >
                <div className={`w-12 h-12 rounded-xl ${c.bg} border ${c.border} flex items-center justify-center mx-auto mb-5`}>
                  <Icon className={`w-5 h-5 ${c.text}`} />
                </div>
                <h3 className="text-white font-semibold text-lg mb-2">{a.title}</h3>
                <p className="text-sm text-slate-400 leading-relaxed">{a.desc}</p>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}