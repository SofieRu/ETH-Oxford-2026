
import React from "react";
import HeroSection from "@/components/landing/HeroSection";
import ProblemSection from "@/components/landing/ProblemSection";
import HowItWorksSection from "@/components/landing/HowItWorksSection";
import ComparisonSection from "@/components/landing/ComparisonSection";
import AudienceSection from "@/components/landing/AudienceSection";

import TradeoffsSection from "@/components/landing/TradeoffsSection";
import TechStackSection from "@/components/landing/TechStackSection";

export default function Home() {
  return (
    <div className="bg-[#0a0e1a] min-h-screen">
      <HeroSection />
      <ProblemSection />
      <HowItWorksSection />
      <ComparisonSection />
      <AudienceSection />
      <TechStackSection />
      <TradeoffsSection />

      {/* Footer */}
      <footer className="border-t border-white/5 py-12 px-4">
        <div className="max-w-4xl mx-auto text-center">
          <p className="text-xs text-slate-500 font-mono">
            Aegis · TEE-Secured Autonomous Trading · Oasis ROFL × Base Sepolia
          </p>
        </div>
      </footer>
    </div>
  );
}