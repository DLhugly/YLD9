"use client";

import { useState } from "react";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { SimpleBondCard } from "~~/components/SimpleBondCard";
import { StakingVaultCard } from "~~/components/StakingVaultCard";
import { TreasuryChart } from "~~/components/TreasuryChart";
import { AutomationPerformance } from "~~/components/AutomationPerformance";
import { Address } from "~~/components/scaffold-eth";

/**
 * Agonic Protocol Dashboard - Ultra-Simple Automated Treasury
 * 80/20 Automated Flywheel: 80% stable-first, 20% growth/buyback
 */
const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [selectedView, setSelectedView] = useState<"overview" | "bonds" | "staking" | "treasury">("overview");

  // Development mock data (controlled by NEXT_PUBLIC_USE_MOCK_DATA)
  const useMockData = process.env.NEXT_PUBLIC_USE_MOCK_DATA === "true";
  
  const mockData = {
    totalTVL: 2450000, // $2.45M TVL
    currentAPY: 12.4, // 80/20 automation APY (Aave + Lido + buybacks)
    ethReserves: 58.6, // ETH accumulated via DCA
    agnPrice: 0.85,
    buybacksActive: true,
    runwayMonths: 18, // Strong runway from 80% stable allocation
    coverageRatio: 1.65, // Healthy coverage from ETH backing
    automatedYield: 4200, // Weekly automated yields (USDC + ETH)
    burnRate: 90, // 90% burn rate from buybacks
    stableAllocation: 80, // 80% to stable yields
    growthAllocation: 20 // 20% to ETH DCA + buybacks
  };

  // TODO: Real contract data (when useMockData = false)
  const realData = {
    totalTVL: 0, // Treasury.getTotalTreasuryValue()
    currentAPY: 0, // Calculate from Aave + Lido yields + buyback returns
    ethReserves: 0, // Treasury.liquidETH + stakedETH
    agnPrice: 0, // Treasury.getAGNPrice()
    buybacksActive: false, // Check Buyback.lastBuybackTime
    runwayMonths: 0, // Calculate from Treasury.getRunwayMonths()
    coverageRatio: 0, // Treasury.getCoverageRatio()
    automatedYield: 0, // Sum of StakingVault + Treasury yields
    burnRate: 90, // Fixed 90% burn rate
    stableAllocation: 80, // Fixed 80% stable allocation
    growthAllocation: 20 // Fixed 20% growth allocation
  };

  const protocolData = useMockData ? mockData : realData;

  const ETHAccumulationMeter = () => {
    const progress = (protocolData.ethReserves / 100) * 100; // Target: 100 ETH
    
    return (
      <div className="relative w-48 h-48 mx-auto">
        {/* Circular progress background */}
        <svg className="w-48 h-48 transform -rotate-90" viewBox="0 0 100 100">
          <circle
            cx="50"
            cy="50"
            r="40"
            stroke="currentColor"
            strokeWidth="8"
            fill="transparent"
            className="text-base-300"
          />
          <circle
            cx="50"
            cy="50"
            r="40"
            stroke="currentColor"
            strokeWidth="8"
            fill="transparent"
            strokeDasharray={`${progress * 2.51} 251`}
            className="text-warning transition-all duration-1000"
            strokeLinecap="round"
          />
        </svg>
        
        {/* Center content */}
        <div className="absolute inset-0 flex flex-col items-center justify-center">
                  <div className="text-3xl mb-1">⚡</div>
        <div className="text-2xl font-bold">{protocolData.ethReserves}</div>
        <div className="text-sm text-base-content/70">ETH</div>
        <div className="text-xs text-base-content/50 mt-1">Treasury</div>
        </div>
        
        {/* Animated particles */}
        <div className="absolute inset-0 pointer-events-none">
          {[...Array(6)].map((_, i) => (
            <div
              key={i}
              className="absolute w-2 h-2 bg-warning rounded-full opacity-60 animate-pulse"
              style={{
                top: `${20 + Math.random() * 60}%`,
                left: `${20 + Math.random() * 60}%`,
                animationDelay: `${i * 0.5}s`,
                animationDuration: `${2 + Math.random() * 2}s`
              }}
            />
          ))}
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-base-200">
      {/* Hero Section */}
      <div className="bg-gradient-to-br from-base-100 to-base-200 border-b border-base-300">
        <div className="container mx-auto px-4 py-8">
          <div className="text-center mb-8">
            <div className="text-6xl mb-4">🏦</div>
            <h1 className="text-4xl font-bold mb-2">ETH Treasury Fortress</h1>
            <p className="text-lg text-base-content/70 mb-6">
              Multi-stablecoin vault with MicroStrategy-style ETH accumulation
            </p>
            
            {/* ETH Accumulation Meter */}
            <div className="mb-6">
              <ETHAccumulationMeter />
            </div>
            
            {/* Quick Stats */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 max-w-2xl mx-auto">
              <div className="text-center">
                <div className="text-2xl font-bold text-primary">${(protocolData.totalTVL / 1000000).toFixed(1)}M</div>
                <div className="text-sm text-base-content/70">Total TVL</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-success">{protocolData.currentAPY}%</div>
                <div className="text-sm text-base-content/70">Current APY</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-warning">{protocolData.ethReserves}</div>
                <div className="text-sm text-base-content/70">ETH Reserves</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-info">${protocolData.agnPrice}</div>
                <div className="text-sm text-base-content/70">AGN Price</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Navigation Tabs */}
      <div className="container mx-auto px-4 py-4">
        <div className="flex justify-center mb-6">
          <div className="bg-base-100 rounded-2xl p-1 shadow-lg">
            {[
              { key: "overview", label: "Overview", icon: "📊" },
              { key: "bonds", label: "Bonds", icon: "🎫" },
              { key: "staking", label: "Staking", icon: "🏪" },
              { key: "treasury", label: "Treasury", icon: "💎" }
            ].map((tab) => (
              <button
                key={tab.key}
                className={`px-6 py-3 rounded-xl font-medium transition-all flex items-center gap-2 ${
                  selectedView === tab.key
                    ? "bg-primary text-primary-content shadow-sm"
                    : "text-base-content/70 hover:text-base-content hover:bg-base-200"
                }`}
                onClick={() => setSelectedView(tab.key as any)}
              >
                <span>{tab.icon}</span>
                <span className="hidden sm:inline">{tab.label}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Content Area */}
        <div className="max-w-7xl mx-auto">
          {selectedView === "overview" && (
            <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
              {/* Your Position Card */}
              <div className="bg-base-100 rounded-3xl p-6 shadow-md">
                <h3 className="text-lg font-semibold mb-4 flex items-center">
                  <span className="text-xl mr-2">👤</span>
                  Your Position
                </h3>
                {connectedAddress ? (
                  <div className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-base-content/70">Vault Shares:</span>
                      <span className="font-medium">1,250.00</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-base-content/70">USD Value:</span>
                      <span className="font-medium">$1,247.50</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-base-content/70">Yield Earned:</span>
                      <span className="font-medium text-success">$62.38</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-base-content/70">ETH Boost:</span>
                      <span className="font-medium text-warning">15%</span>
                    </div>
                  </div>
                ) : (
                  <div className="text-center py-8 text-base-content/50">
                    Connect wallet to view position
                  </div>
                )}
              </div>

              {/* Automated Allocation */}
              <div className="bg-base-100 rounded-3xl p-6 shadow-md">
                <h3 className="text-lg font-semibold mb-4 flex items-center">
                  <span className="text-xl mr-2">🤖</span>
                  80/20 Automation
                </h3>
                <div className="space-y-3">
                  <div className="flex justify-between">
                    <span className="text-base-content/70">Stable Allocation:</span>
                    <span className="font-medium text-success">{protocolData.stableAllocation}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-base-content/70">Growth Allocation:</span>
                    <span className="font-medium text-warning">{protocolData.growthAllocation}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-base-content/70">ETH DCA:</span>
                    <span className="font-medium text-info">10%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-base-content/70">AGN Buybacks:</span>
                    <span className="font-medium text-error">10%</span>
                  </div>
                  <div className="border-t pt-3">
                    <div className="flex justify-between">
                      <span className="text-base-content/70">Burn Rate:</span>
                      <span className="font-medium text-error">{protocolData.burnRate}%</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-base-content/70">Net APY:</span>
                      <span className="font-medium text-success">{protocolData.currentAPY}%</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Safety Gates */}
              <div className="bg-base-100 rounded-3xl p-6 shadow-md">
                <h3 className="text-lg font-semibold mb-4 flex items-center">
                  <span className="text-xl mr-2">🛡️</span>
                  Safety Gates
                </h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-base-content/70">Runway:</span>
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 bg-success rounded-full"></div>
                      <span className="font-medium">{protocolData.runwayMonths}m</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-base-content/70">Coverage Ratio:</span>
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 bg-success rounded-full"></div>
                      <span className="font-medium">{protocolData.coverageRatio}×</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-base-content/70">Buybacks:</span>
                    <div className="flex items-center gap-2">
                      <div className={`w-3 h-3 rounded-full ${protocolData.buybacksActive ? "bg-success" : "bg-error"}`}></div>
                      <span className="font-medium">{protocolData.buybacksActive ? "Active" : "Paused"}</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Automation Performance Component */}
              <div className="lg:col-span-2 xl:col-span-3">
                <AutomationPerformance />
              </div>
            </div>
          )}

          {selectedView === "bonds" && (
            <div className="max-w-lg mx-auto">
              <SimpleBondCard />
            </div>
          )}

          {selectedView === "staking" && (
            <div className="max-w-lg mx-auto">
              <StakingVaultCard />
            </div>
          )}

          {selectedView === "treasury" && (
            <TreasuryChart />
          )}


        </div>
      </div>
    </div>
  );
};

export default Home;