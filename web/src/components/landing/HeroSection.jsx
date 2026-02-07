import React from "react";
import { motion } from "framer-motion";
import { Shield, Lock, ArrowDown, ArrowRight } from "lucide-react";
import { Link } from "react-router-dom";
import { createPageUrl } from "@/utils";
import { Button } from "@/components/ui/button";

export default function HeroSection() {
  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden px-4">
      {/* Animated grid background */}
      <div className="absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage: `linear-gradient(rgba(0,212,170,0.3) 1px, transparent 1px), linear-gradient(90deg, rgba(0,212,170,0.3) 1px, transparent 1px)`,
          backgroundSize: '60px 60px'
        }}
      />
      
      {/* Glow orbs */}
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-emerald-500/10 rounded-full blur-[120px]" />
      <div className="absolute bottom-1/4 right-1/4 w-80 h-80 bg-blue-500/8 rounded-full blur-[100px]" />

      <div className="relative z-10 max-w-4xl mx-auto text-center">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: "easeOut" }}
        >
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full border border-emerald-500/20 bg-emerald-500/5 mb-8">
            <div className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            <span className="text-emerald-400 text-sm font-mono tracking-wide">AEGIS · TRUSTLESS EXECUTION</span>
          </div>
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.15, ease: "easeOut" }}
          className="text-5xl sm:text-6xl md:text-7xl font-bold text-white leading-[1.05] tracking-tight"
        >
          Your Keys.{" "}
          <span className="bg-gradient-to-r from-emerald-400 via-teal-300 to-blue-400 bg-clip-text text-transparent">
            No One Else's.
          </span>
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.3, ease: "easeOut" }}
          className="mt-6 text-lg sm:text-xl text-slate-400 max-w-2xl mx-auto leading-relaxed"
        >
          An autonomous trading bot that generates and guards its own private keys
          inside a <span className="text-white font-medium">Trusted Execution Environment</span>—
          where not even the developer can look inside.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.45, ease: "easeOut" }}
          className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4"
        >
          <div className="flex items-center gap-3 px-5 py-3 rounded-xl bg-white/5 border border-white/10">
            <Shield className="w-5 h-5 text-emerald-400" />
            <span className="text-white text-sm font-medium">TEE-Secured</span>
          </div>
          <div className="flex items-center gap-3 px-5 py-3 rounded-xl bg-white/5 border border-white/10">
            <Lock className="w-5 h-5 text-blue-400" />
            <span className="text-white text-sm font-medium">Non-Custodial</span>
          </div>
          <div className="flex items-center gap-3 px-5 py-3 rounded-xl bg-white/5 border border-white/10">
            <span className="font-mono text-emerald-400 text-sm">⟠</span>
            <span className="text-white text-sm font-medium">Base Sepolia</span>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.6, ease: "easeOut" }}
          className="mt-10"
        >
          <Link to={createPageUrl("Trading")}>
            <Button size="lg" className="bg-emerald-600 hover:bg-emerald-700 text-white px-8 py-6 text-base">
              Launch Trading Platform
              <ArrowRight className="w-5 h-5 ml-2" />
            </Button>
          </Link>
        </motion.div>

        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.2, duration: 1 }}
          className="mt-20"
        >
          <ArrowDown className="w-5 h-5 text-slate-500 mx-auto animate-bounce" />
        </motion.div>
      </div>
    </section>
  );
}