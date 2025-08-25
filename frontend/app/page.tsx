"use client";

import { useState } from "react";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { VaultCard } from "~~/components/VaultCard";
import { TreasuryChart } from "~~/components/TreasuryChart";
import { Address } from "~~/components/scaffold-eth";

/**
 * Agonic Dashboard - ETH Treasury Fortress theme
 * Based on UI_FRONTEND.md specifications
 */
const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [selectedView, setSelectedView] = useState<"overview" | "vault" | "treasury" | "notes">("overview");

  // Mock data for dashboard tiles
  const mockData = {
    totalTVL: 2450000,
    currentAPY: 5.2,
    ethReserves: 58.6,
    agnPrice: 0.85,
    buybacksActive: true,
    runwayMonths: 8.2,
    coverageRatio: 1.45,
    fxProfits: 1247
  };

  const ETHAccumulationMeter = () => {
    const progress = (mockData.ethReserves / 100) * 100; // Target: 100 ETH
    
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
          <div className="text-2xl font-bold">{mockData.ethReserves}</div>
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
                <div className="text-2xl font-bold text-primary">${(mockData.totalTVL / 1000000).toFixed(1)}M</div>
                <div className="text-sm text-base-content/70">Total TVL</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-success">{mockData.currentAPY}%</div>
                <div className="text-sm text-base-content/70">Current APY</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-warning">{mockData.ethReserves}</div>
                <div className="text-sm text-base-content/70">ETH Reserves</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-info">${mockData.agnPrice}</div>
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
              { key: "vault", label: "Vault", icon: "🏦" },
              { key: "treasury", label: "Treasury", icon: "🏛️" },
              { key: "notes", label: "ATN Notes", icon: "📄" }
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

              {/* Vault Overview */}
              <div className="bg-base-100 rounded-3xl p-6 shadow-md">
                <h3 className="text-lg font-semibold mb-4 flex items-center">
                  <span className="text-xl mr-2">📈</span>
                  Vault Overview
                </h3>
                <div className="space-y-3">
                  <div className="flex justify-between">
                    <span className="text-base-content/70">USDC:</span>
                    <span className="font-medium">45%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-base-content/70">USD1:</span>
                    <span className="font-medium">30%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-base-content/70">EURC:</span>
                    <span className="font-medium">25%</span>
                  </div>
                  <div className="border-t pt-3">
                    <div className="flex justify-between">
                      <span className="text-base-content/70">Net APY:</span>
                      <span className="font-medium text-success">{mockData.currentAPY}%</span>
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
                      <span className="font-medium">{mockData.runwayMonths}m</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-base-content/70">Coverage Ratio:</span>
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 bg-success rounded-full"></div>
                      <span className="font-medium">{mockData.coverageRatio}×</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-base-content/70">Buybacks:</span>
                    <div className="flex items-center gap-2">
                      <div className={`w-3 h-3 rounded-full ${mockData.buybacksActive ? "bg-success" : "bg-error"}`}></div>
                      <span className="font-medium">{mockData.buybacksActive ? "Active" : "Paused"}</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* FX Arbitrage Stats */}
              <div className="bg-base-100 rounded-3xl p-6 shadow-md lg:col-span-2 xl:col-span-3">
                <h3 className="text-lg font-semibold mb-4 flex items-center">
                  <span className="text-xl mr-2">⚡</span>
                  FX Arbitrage Performance
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div className="text-center">
                    <div className="text-2xl font-bold text-success">${mockData.fxProfits}</div>
                    <div className="text-sm text-base-content/70">Total FX Profits</div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-info">0.1%</div>
                    <div className="text-sm text-base-content/70">Auto Threshold</div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-warning">24</div>
                    <div className="text-sm text-base-content/70">Opportunities This Week</div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {selectedView === "vault" && (
            <div className="flex justify-center">
              <VaultCard />
            </div>
          )}

          {selectedView === "treasury" && (
            <TreasuryChart />
          )}

          {selectedView === "notes" && (
            <div className="bg-base-100 rounded-3xl p-8 shadow-md text-center">
              <div className="text-6xl mb-4">📄</div>
              <h2 className="text-2xl font-bold mb-2">ATN Notes</h2>
              <p className="text-base-content/70 mb-6">
                Fixed-APR treasury notes coming soon
              </p>
              <div className="bg-base-200 rounded-2xl p-6">
                <h3 className="font-semibold mb-4">ATN-01 Tranche</h3>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
                  <div>
                    <div className="text-base-content/70">APR:</div>
                    <div className="font-medium text-lg">8%</div>
                  </div>
                  <div>
                    <div className="text-base-content/70">Term:</div>
                    <div className="font-medium text-lg">6 months</div>
                  </div>
                  <div>
                    <div className="text-base-content/70">Cap:</div>
                    <div className="font-medium text-lg">$250k</div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Home;