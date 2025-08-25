"use client";

import { useState, useEffect } from "react";
import { useReadContract } from "wagmi";
import { formatEther } from "viem";

/**
 * TreasuryChart component - ETH accumulation and FX arbitrage tracking
 * Based on UI_FRONTEND.md "ETH Treasury Fortress" theme with 3D-like vault visualization
 */
export const TreasuryChart = () => {
  const [selectedTimeframe, setSelectedTimeframe] = useState<"1W" | "1M" | "3M" | "1Y">("1M");
  const [showFXLogs, setShowFXLogs] = useState(false);

  // Mock treasury contract address
  const TREASURY_ADDRESS = "0x0000000000000000000000000000000000000000";

  // Read treasury data (mock for now)
  const { data: ethBreakdown } = useReadContract({
    address: TREASURY_ADDRESS,
    abi: [
      {
        name: "getETHBreakdown",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [
          { name: "liquid", type: "uint256" },
          { name: "staked", type: "uint256" },
          { name: "rewards", type: "uint256" }
        ]
      }
    ],
    functionName: "getETHBreakdown"
  });

  const { data: safetyGates } = useReadContract({
    address: TREASURY_ADDRESS,
    abi: [
      {
        name: "getSafetyGateStatus", 
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [
          { name: "runwayOK", type: "bool" },
          { name: "crOK", type: "bool" }
        ]
      }
    ],
    functionName: "getSafetyGateStatus"
  });

  // Mock data for development
  const mockETHData = {
    liquid: 45.2,
    staked: 12.8,
    rewards: 0.6,
    total: 58.6
  };

  const mockDCAHistory = [
    { date: "2024-08-18", usdcAmount: 5000, ethAmount: 1.67, ethPrice: 2995 },
    { date: "2024-08-11", usdcAmount: 5000, ethAmount: 1.72, ethPrice: 2907 },
    { date: "2024-08-04", usdcAmount: 5000, ethAmount: 1.61, ethPrice: 3106 },
    { date: "2024-07-28", usdcAmount: 5000, ethAmount: 1.58, ethPrice: 3165 },
  ];

  const mockFXArbitrage = [
    { timestamp: "2024-08-20 14:30", pair: "EURC/USDC", amount: 10000, profit: 12.5, type: "arbitrage" },
    { timestamp: "2024-08-19 09:15", pair: "USD1/USDC", amount: 7500, profit: 8.3, type: "arbitrage" },
    { timestamp: "2024-08-18 16:45", pair: "EURC/USD1", amount: 15000, profit: 18.7, type: "arbitrage" },
  ];

  const mockChartData = [
    { week: "W1", eth: 52.1 },
    { week: "W2", eth: 53.8 },
    { week: "W3", eth: 55.4 },
    { week: "W4", eth: 58.6 },
  ];

  return (
    <div className="bg-base-100 border-base-300 border shadow-md shadow-secondary rounded-3xl p-6 w-full">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center">
          <span className="text-3xl mr-3">🏛️</span>
          <div>
            <h2 className="text-xl font-bold">ETH Treasury</h2>
            <p className="text-sm text-base-content/70">MicroStrategy-style accumulation</p>
          </div>
        </div>
        
        {/* Safety Gates */}
        <div className="flex gap-2">
          <div className={`flex items-center gap-1 px-2 py-1 rounded-lg text-xs ${
            safetyGates?.[0] ? "bg-success/20 text-success" : "bg-error/20 text-error"
          }`}>
            <div className={`w-2 h-2 rounded-full ${
              safetyGates?.[0] ? "bg-success" : "bg-error"
            }`}></div>
            RUNWAY
          </div>
          <div className={`flex items-center gap-1 px-2 py-1 rounded-lg text-xs ${
            safetyGates?.[1] ? "bg-success/20 text-success" : "bg-error/20 text-error"
          }`}>
            <div className={`w-2 h-2 rounded-full ${
              safetyGates?.[1] ? "bg-success" : "bg-error"
            }`}></div>
            CR
          </div>
        </div>
      </div>

      {/* ETH Holdings Breakdown */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        {/* 3D-like Vault Visualization */}
        <div className="bg-gradient-to-br from-base-200 to-base-300 rounded-2xl p-6 relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-r from-yellow-500/10 to-orange-500/10 rounded-2xl"></div>
          <div className="relative z-10">
            <h3 className="font-semibold mb-4 flex items-center">
              <span className="text-lg mr-2">💎</span>
              ETH Crystals
            </h3>
            
            {/* Visual representation of ETH stacking */}
            <div className="flex items-end justify-center h-32 gap-2">
              {/* Liquid ETH */}
              <div className="flex flex-col items-center">
                <div 
                  className="bg-gradient-to-t from-blue-500 to-blue-300 rounded-t-lg shadow-lg"
                  style={{ 
                    width: '40px', 
                    height: `${(mockETHData.liquid / mockETHData.total) * 120}px`,
                    minHeight: '20px'
                  }}
                ></div>
                <div className="text-xs mt-1 font-medium">Liquid</div>
                <div className="text-xs text-base-content/70">{mockETHData.liquid} ETH</div>
              </div>
              
              {/* Staked ETH */}
              <div className="flex flex-col items-center">
                <div 
                  className="bg-gradient-to-t from-purple-500 to-purple-300 rounded-t-lg shadow-lg"
                  style={{ 
                    width: '40px', 
                    height: `${(mockETHData.staked / mockETHData.total) * 120}px`,
                    minHeight: '20px'
                  }}
                ></div>
                <div className="text-xs mt-1 font-medium">Staked</div>
                <div className="text-xs text-base-content/70">{mockETHData.staked} ETH</div>
              </div>
              
              {/* Rewards */}
              <div className="flex flex-col items-center">
                <div 
                  className="bg-gradient-to-t from-green-500 to-green-300 rounded-t-lg shadow-lg"
                  style={{ 
                    width: '40px', 
                    height: `${(mockETHData.rewards / mockETHData.total) * 120}px`,
                    minHeight: '20px'
                  }}
                ></div>
                <div className="text-xs mt-1 font-medium">Rewards</div>
                <div className="text-xs text-base-content/70">{mockETHData.rewards} ETH</div>
              </div>
            </div>
            
            <div className="mt-4 text-center">
              <div className="text-2xl font-bold">{mockETHData.total} ETH</div>
              <div className="text-sm text-base-content/70">Total Treasury</div>
            </div>
          </div>
        </div>

        {/* ETH Accumulation Chart */}
        <div className="bg-base-200 rounded-2xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold flex items-center">
              <span className="text-lg mr-2">📈</span>
              ETH Accumulation
            </h3>
            <div className="flex bg-base-100 rounded-lg p-1">
              {["1W", "1M", "3M", "1Y"].map((timeframe) => (
                <button
                  key={timeframe}
                  className={`px-3 py-1 rounded text-xs font-medium transition-all ${
                    selectedTimeframe === timeframe
                      ? "bg-primary text-primary-content"
                      : "hover:bg-base-300"
                  }`}
                  onClick={() => setSelectedTimeframe(timeframe as any)}
                >
                  {timeframe}
                </button>
              ))}
            </div>
          </div>
          
          {/* Simple line chart representation */}
          <div className="h-24 flex items-end justify-between">
            {mockChartData.map((point, index) => (
              <div key={point.week} className="flex flex-col items-center">
                <div 
                  className="bg-primary rounded-t w-8 transition-all hover:bg-primary/80"
                  style={{ height: `${(point.eth / 60) * 80}px` }}
                  title={`${point.week}: ${point.eth} ETH`}
                ></div>
                <div className="text-xs mt-1 text-base-content/70">{point.week}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Toggle Buttons */}
      <div className="flex gap-2 mb-4">
        <button
          className={`btn btn-sm ${showFXLogs ? "btn-outline" : "btn-primary"}`}
          onClick={() => setShowFXLogs(false)}
        >
          DCA History
        </button>
        <button
          className={`btn btn-sm ${showFXLogs ? "btn-primary" : "btn-outline"}`}
          onClick={() => setShowFXLogs(true)}
        >
          FX Arbitrage
        </button>
      </div>

      {/* Transaction Logs */}
      <div className="bg-base-200 rounded-2xl p-4">
        <h3 className="font-semibold mb-3 flex items-center">
          <span className="text-lg mr-2">{showFXLogs ? "⚡" : "🔄"}</span>
          {showFXLogs ? "FX Arbitrage Log" : "DCA Purchase History"}
        </h3>
        
        <div className="space-y-2 max-h-48 overflow-y-auto">
          {showFXLogs ? (
            mockFXArbitrage.map((tx, index) => (
              <div key={index} className="flex items-center justify-between p-3 bg-base-100 rounded-lg">
                <div className="flex items-center gap-3">
                  <div className="w-2 h-2 bg-success rounded-full"></div>
                  <div>
                    <div className="font-medium text-sm">{tx.pair}</div>
                    <div className="text-xs text-base-content/70">{tx.timestamp}</div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-medium text-sm">${tx.amount.toLocaleString()}</div>
                  <div className="text-xs text-success">+${tx.profit}</div>
                </div>
              </div>
            ))
          ) : (
            mockDCAHistory.map((tx, index) => (
              <div key={index} className="flex items-center justify-between p-3 bg-base-100 rounded-lg">
                <div className="flex items-center gap-3">
                  <div className="w-2 h-2 bg-primary rounded-full"></div>
                  <div>
                    <div className="font-medium text-sm">Weekly DCA</div>
                    <div className="text-xs text-base-content/70">{tx.date}</div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-medium text-sm">{tx.ethAmount} ETH</div>
                  <div className="text-xs text-base-content/70">${tx.usdcAmount} @ ${tx.ethPrice}</div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Automated FX Thresholds Status */}
      <div className="mt-4 p-3 bg-info/10 rounded-lg border border-info/20">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="text-info">⚙️</span>
            <span className="text-sm font-medium">Automated FX Arbitrage</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 bg-success rounded-full animate-pulse"></div>
            <span className="text-xs text-success">Active (0.1% threshold)</span>
          </div>
        </div>
      </div>
    </div>
  );
};
