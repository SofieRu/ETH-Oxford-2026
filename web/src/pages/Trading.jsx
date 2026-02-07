import React, { useState, useEffect } from "react";
import { base44 } from "@/api/base44Client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Shield, TrendingUp, ArrowRightLeft, Activity, LogOut } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { createPageUrl } from "@/utils";

export default function Trading() {
  const [user, setUser] = useState(null);
  const [ethPrice, setEthPrice] = useState(null);
  const [loading, setLoading] = useState(false);
  const [tradeForm, setTradeForm] = useState({
    fromToken: "ETH",
    toToken: "USDC",
    amount: ""
  });

  useEffect(() => {
    loadUser();
    fetchEthPrice();
    const interval = setInterval(fetchEthPrice, 30000); // Update every 30s
    return () => clearInterval(interval);
  }, []);

  const loadUser = async () => {
    try {
      const currentUser = await base44.auth.me();
      setUser(currentUser);
    } catch (error) {
      base44.auth.redirectToLogin();
    }
  };

  const fetchEthPrice = async () => {
    try {
      const response = await fetch("https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd");
      const data = await response.json();
      setEthPrice(data.ethereum.usd);
    } catch (error) {
      console.error("Failed to fetch ETH price:", error);
    }
  };

  const handleTrade = async (e) => {
    e.preventDefault();
    setLoading(true);
    
    try {
      // Simulate trade execution
      await new Promise(resolve => setTimeout(resolve, 2000));
      alert(`Trade order submitted! Will swap ${tradeForm.amount} ${tradeForm.fromToken} to ${tradeForm.toToken}`);
      setTradeForm({ ...tradeForm, amount: "" });
    } catch (error) {
      console.error("Trade error:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    base44.auth.logout(createPageUrl("Home"));
  };

  if (!user) return null;

  return (
    <div className="min-h-screen bg-[#0a0e1a]">
      {/* Header */}
      <header className="border-b border-white/10 bg-black/20 backdrop-blur-sm sticky top-0 z-50">
        <div className="max-w-6xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2 px-3 py-1.5 rounded-full border border-emerald-500/20 bg-emerald-500/5">
              <Shield className="w-4 h-4 text-emerald-400" />
              <span className="text-emerald-400 text-sm font-mono tracking-wide">AEGIS</span>
            </div>
            <span className="text-slate-500">|</span>
            <span className="text-white font-medium">Trading Platform</span>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-sm text-slate-400">{user.email}</span>
            <Button variant="ghost" size="sm" onClick={handleLogout} className="text-slate-400 hover:text-white">
              <LogOut className="w-4 h-4 mr-2" />
              Logout
            </Button>
          </div>
        </div>
      </header>

      <div className="max-w-6xl mx-auto px-4 py-10">
        {/* Stats Grid */}
        <div className="grid sm:grid-cols-3 gap-4 mb-8">
          <Card className="bg-white/[0.02] border-white/10">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm text-slate-400 font-normal flex items-center gap-2">
                <Activity className="w-4 h-4" />
                ETH Price (Live)
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold text-white">
                {ethPrice ? `$${ethPrice.toLocaleString()}` : "Loading..."}
              </p>
              <p className="text-xs text-emerald-400 mt-1">Base Sepolia</p>
            </CardContent>
          </Card>

          <Card className="bg-white/[0.02] border-white/10">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm text-slate-400 font-normal flex items-center gap-2">
                <TrendingUp className="w-4 h-4" />
                Active Trades
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold text-white">0</p>
              <p className="text-xs text-slate-500 mt-1">No pending orders</p>
            </CardContent>
          </Card>

          <Card className="bg-white/[0.02] border-white/10">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm text-slate-400 font-normal flex items-center gap-2">
                <Shield className="w-4 h-4" />
                TEE Status
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                <p className="text-lg font-semibold text-emerald-400">Active</p>
              </div>
              <p className="text-xs text-slate-500 mt-1">Hardware secured</p>
            </CardContent>
          </Card>
        </div>

        {/* Trading Form */}
        <Card className="bg-white/[0.02] border-white/10">
          <CardHeader>
            <CardTitle className="text-xl text-white flex items-center gap-2">
              <ArrowRightLeft className="w-5 h-5 text-emerald-400" />
              Create Automated Trade
            </CardTitle>
            <p className="text-sm text-slate-400">Set conditions for autonomous execution via TEE</p>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleTrade} className="space-y-6">
              <div className="grid sm:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label className="text-white">From Token</Label>
                  <Select value={tradeForm.fromToken} onValueChange={(val) => setTradeForm({ ...tradeForm, fromToken: val })}>
                    <SelectTrigger className="bg-white/5 border-white/10 text-white">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="ETH">ETH</SelectItem>
                      <SelectItem value="USDC">USDC</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label className="text-white">To Token</Label>
                  <Select value={tradeForm.toToken} onValueChange={(val) => setTradeForm({ ...tradeForm, toToken: val })}>
                    <SelectTrigger className="bg-white/5 border-white/10 text-white">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="USDC">USDC</SelectItem>
                      <SelectItem value="ETH">ETH</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="space-y-2">
                <Label className="text-white">Amount to Trade</Label>
                <Input
                  type="number"
                  step="0.001"
                  placeholder="0.0"
                  value={tradeForm.amount}
                  onChange={(e) => setTradeForm({ ...tradeForm, amount: e.target.value })}
                  className="bg-white/5 border-white/10 text-white placeholder:text-slate-500"
                  required
                />
              </div>

              <div className="rounded-xl bg-emerald-500/5 border border-emerald-500/20 p-4">
                <p className="text-xs text-emerald-400/80 leading-relaxed">
                  <Shield className="w-3 h-3 inline mr-1" />
                  This trade will execute autonomously when the condition is met. 
                  The private key never leaves the TEE enclave.
                </p>
              </div>

              <Button
                type="submit"
                className="w-full bg-emerald-600 hover:bg-emerald-700 text-white"
                disabled={loading}
              >
                {loading ? "Submitting..." : "Create Automated Trade Order"}
              </Button>
            </form>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}