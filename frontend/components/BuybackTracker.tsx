"use client";

import { useState, useEffect } from "react";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";
import { useMemo } from "react";

interface BuybackExecution {
  id: string;
  timestamp: Date;
  usdcSpent: number;
  agnBought: number;
  agnBurned: number;
  agnToTreasury: number;
  avgPrice: number;
  twapPeriod: string;
  txHash: string;
}

interface SafetyGate {
  name: string;
  status: "healthy" | "warning" | "critical";
  currentValue: number;
  threshold: number;
  unit: string;
  description: string;
}

interface TWAPData {
  timestamp: Date;
  price: number;
  volume: number;
}

export default function BuybackTracker() {
  const [buybackHistory, setBuybackHistory] = useState<BuybackExecution[]>([]);
  const [safetyGates, setSafetyGates] = useState<SafetyGate[]>([]);
  const [twapData, setTwapData] = useState<TWAPData[]>([]);
  const useMockData = process.env.NEXT_PUBLIC_USE_MOCK_DATA !== "false";

  // Read buyback contract data
  const { data: buybackStats } = useScaffoldReadContract({
    contractName: "Buyback",
    functionName: "getBuybackStats",
    watch: true
  });

  const { data: safetyGateStatus } = useScaffoldReadContract({
    contractName: "Buyback", 
    functionName: "getSafetyGateStatus",
    watch: true
  });

  const [totalStats, setTotalStats] = useState({
    totalUSDCSpent: 0,
    totalAGNBought: 0,
    totalAGNBurned: 0,
    totalAGNToTreasury: 0,
    avgPrice: 0,
    burnRate: 90 // Updated to match 90/10 split from contracts
  });

  useEffect(() => {
    // Use real contract data if available, fall back to mock
    if (!useMockData && buybackStats) {
      setTotalStats({
        totalUSDCSpent: Number(buybackStats.totalUSDCSpent) / 1e6, // Convert from wei
        totalAGNBought: Number(buybackStats.totalAGNBought) / 1e18,
        totalAGNBurned: Number(buybackStats.totalAGNBurned) / 1e18, 
        totalAGNToTreasury: Number(buybackStats.totalAGNToTreasury) / 1e18,
        avgPrice: Number(buybackStats.totalUSDCSpent) / Number(buybackStats.totalAGNBought),
        burnRate: 90 // 90/10 split from contracts
      });
    } else {
      // Mock data - fallback for development
      const mockBuybacks: BuybackExecution[] = [
        {
          id: "buyback-1",
          timestamp: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
          usdcSpent: 5000,
          agnBought: 50000,
          agnBurned: 45000, // Updated to 90% burn
          agnToTreasury: 5000, // Updated to 10% treasury
          avgPrice: 0.10,
          twapPeriod: "7-day",
          txHash: "0x123...abc"
        },
      {
        id: "buyback-2", 
        timestamp: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000),
        usdcSpent: 4500,
        agnBought: 47368,
        agnBurned: 42631, // Updated to 90% burn
        agnToTreasury: 4737, // Updated to 10% treasury
        avgPrice: 0.095,
        twapPeriod: "7-day",
        txHash: "0x456...def"
      },
      {
        id: "buyback-3",
        timestamp: new Date(Date.now() - 21 * 24 * 60 * 60 * 1000),
        usdcSpent: 3800,
        agnBought: 42222,
        agnBurned: 38000, // Updated to 90% burn
        agnToTreasury: 4222, // Updated to 10% treasury
        avgPrice: 0.09,
        twapPeriod: "7-day",
        txHash: "0x789...ghi"
      },
      {
        id: "buyback-4",
        timestamp: new Date(Date.now() - 28 * 24 * 60 * 60 * 1000),
        usdcSpent: 4200,
        agnBought: 48837,
        agnBurned: 43953, // Updated to 90% burn
        agnToTreasury: 4884, // Updated to 10% treasury
        avgPrice: 0.086,
        twapPeriod: "7-day",
        txHash: "0xabc...123"
      }
    ];

    const mockSafetyGates: SafetyGate[] = [
      {
        name: "Runway Buffer",
        status: "healthy",
        currentValue: 8.5,
        threshold: 6.0,
        unit: "months",
        description: "Treasury runway for operational expenses"
      },
      {
        name: "Coverage Ratio",
        status: "healthy", 
        currentValue: 1.45,
        threshold: 1.20,
        unit: "x",
        description: "ETH treasury value vs outstanding ATN bonds"
      },
      {
        name: "Weekly DCA Limit",
        status: "warning",
        currentValue: 4800,
        threshold: 5000,
        unit: "USDC",
        description: "Remaining weekly ETH purchase capacity"
      },
      {
        name: "Liquidity Threshold",
        status: "healthy",
        currentValue: 85,
        threshold: 70,
        unit: "%",
        description: "AGN token liquidity for smooth buybacks"
      }
    ];

    const mockTWAP: TWAPData[] = [
      { timestamp: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000), price: 0.082, volume: 15000 },
      { timestamp: new Date(Date.now() - 25 * 24 * 60 * 60 * 1000), price: 0.086, volume: 18000 },
      { timestamp: new Date(Date.now() - 20 * 24 * 60 * 60 * 1000), price: 0.090, volume: 22000 },
      { timestamp: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000), price: 0.095, volume: 19000 },
      { timestamp: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000), price: 0.100, volume: 25000 },
      { timestamp: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000), price: 0.105, volume: 28000 },
      { timestamp: new Date(), price: 0.108, volume: 30000 }
    ];

    setBuybackHistory(mockBuybacks);
    setSafetyGates(mockSafetyGates);
    setTwapData(mockTWAP);

    // Calculate total stats
      const totals = mockBuybacks.reduce((acc, buyback) => ({
        totalUSDCSpent: acc.totalUSDCSpent + buyback.usdcSpent,
        totalAGNBought: acc.totalAGNBought + buyback.agnBought,
        totalAGNBurned: acc.totalAGNBurned + buyback.agnBurned,
        totalAGNToTreasury: acc.totalAGNToTreasury + buyback.agnToTreasury,
        avgPrice: 0, // Will calculate after
        burnRate: 90
      }), { totalUSDCSpent: 0, totalAGNBought: 0, totalAGNBurned: 0, totalAGNToTreasury: 0, avgPrice: 0, burnRate: 90 });

      totals.avgPrice = totals.totalUSDCSpent / totals.totalAGNBought;
      setTotalStats(totals);
    }
  }, [buybackStats, useMockData]);

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2
    }).format(amount);
  };

  const formatNumber = (num: number) => {
    return new Intl.NumberFormat('en-US').format(num);
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const burnTreasuryData = [
    { name: "Burned", value: totalStats.totalAGNBurned, color: "#ef4444" },
    { name: "To Treasury", value: totalStats.totalAGNToTreasury, color: "#3b82f6" }
  ];

  return (
    <div className="bg-base-100 border-base-300 border shadow-md shadow-secondary rounded-3xl p-6 w-full">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center">
          <span className="text-3xl mr-3">🔥</span>
          <div>
            <h2 className="text-xl font-bold">AGN Buyback Tracker</h2>
            <p className="text-sm text-base-content/70">
              Weekly TWAP buybacks with 90/10 burn/treasury split
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-lg">🔥</span>
          <span className="text-sm text-base-content/70">Deflationary</span>
        </div>
      </div>

      <div className="tabs tabs-boxed justify-start mb-6">
        <a className="tab tab-active">Overview</a>
        <a className="tab">Safety Gates</a>
        <a className="tab">History</a>
      </div>

      <div className="space-y-6">
        {/* Key Stats */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-base-content/70">Total USDC Spent</span>
              <span className="text-lg">💰</span>
            </div>
            <div className="text-2xl font-bold">{formatCurrency(totalStats.totalUSDCSpent)}</div>
            <div className="text-xs text-base-content/60">
              Across {buybackHistory.length} buybacks
            </div>
          </div>

          <div className="bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-base-content/70">AGN Bought</span>
              <span className="text-lg">📈</span>
            </div>
            <div className="text-2xl font-bold">{formatNumber(totalStats.totalAGNBought)}</div>
            <div className="text-xs text-base-content/60">
              Avg price: ${totalStats.avgPrice.toFixed(4)}
            </div>
          </div>

          <div className="bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-base-content/70">AGN Burned</span>
              <span className="text-lg">🔥</span>
            </div>
            <div className="text-2xl font-bold text-error">{formatNumber(totalStats.totalAGNBurned)}</div>
            <div className="text-xs text-base-content/60">
              90% burn rate
            </div>
          </div>

          <div className="bg-base-200 rounded-xl p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-base-content/70">To Treasury</span>
              <span className="text-lg">🏛️</span>
            </div>
            <div className="text-2xl font-bold text-info">{formatNumber(totalStats.totalAGNToTreasury)}</div>
            <div className="text-xs text-base-content/60">
              10% to treasury
            </div>
          </div>
        </div>

        {/* Burn/Treasury Split Visualization */}
        <div className="grid gap-4 md:grid-cols-2">
          <div className="bg-base-200 rounded-xl p-6">
            <h3 className="font-semibold mb-2 flex items-center">
              <span className="text-lg mr-2">📊</span>
              AGN Distribution
            </h3>
            <p className="text-sm text-base-content/70 mb-4">90/10 burn/treasury split</p>
            
            {/* Simple Progress Bars */}
            <div className="space-y-4">
              <div>
                <div className="flex justify-between items-center mb-1">
                  <span className="text-sm">Burned (90%)</span>
                  <span className="text-sm font-bold text-error">{formatNumber(totalStats.totalAGNBurned)}</span>
                </div>
                <div className="w-full bg-base-300 rounded-full h-2">
                  <div className="bg-error h-2 rounded-full" style={{ width: "90%" }}></div>
                </div>
              </div>
              
              <div>
                <div className="flex justify-between items-center mb-1">
                  <span className="text-sm">To Treasury (10%)</span>
                  <span className="text-sm font-bold text-info">{formatNumber(totalStats.totalAGNToTreasury)}</span>
                </div>
                <div className="w-full bg-base-300 rounded-full h-2">
                  <div className="bg-info h-2 rounded-full" style={{ width: "10%" }}></div>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-base-200 rounded-xl p-6">
            <h3 className="font-semibold mb-2 flex items-center">
              <span className="text-lg mr-2">📅</span>
              Next Buyback
            </h3>
            <p className="text-sm text-base-content/70 mb-4">Scheduled execution details</p>
            
            <div className="space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm">Next Execution:</span>
                <div className="badge badge-outline">
                  📅 In 3 days
                </div>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm">Estimated Amount:</span>
                <span className="font-semibold">~$4,200</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm">Current AGN Price:</span>
                <span className="font-semibold">$0.108</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm">Expected AGN:</span>
                <span className="font-semibold">~38,888 AGN</span>
              </div>
              <div className="pt-2 border-t border-base-300">
                <div className="flex justify-between items-center text-sm">
                  <span>Will Burn:</span>
                  <span className="text-error font-semibold">~35,000 AGN</span>
                </div>
                <div className="flex justify-between items-center text-sm">
                  <span>To Treasury:</span>
                  <span className="text-info font-semibold">~3,888 AGN</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
