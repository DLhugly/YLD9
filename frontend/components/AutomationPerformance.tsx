"use client";

import { useState } from "react";

interface AutomationMetrics {
  aaveAPY: number;
  lidoAPY: number;
  totalYieldGenerated: number;
  lastHarvestTime: Date;
  nextHarvestTime: Date;
  agnBurnRate: number;
  ethAccumulated: number;
  runwayMonths: number;
}

/**
 * AutomationPerformance component - Tracks the 80/20 automated flywheel
 * Replaces the complex multi-protocol StrategyPerformance
 */
export const AutomationPerformance = () => {
  const [selectedTimeframe, setSelectedTimeframe] = useState<"1W" | "1M" | "3M">("1M");
  
  // Mock data controlled by env variable
  const useMockData = process.env.NEXT_PUBLIC_USE_MOCK_DATA === "true";
  
  const mockMetrics: AutomationMetrics = {
    aaveAPY: 8.2,
    lidoAPY: 3.8,
    totalYieldGenerated: 2847,
    lastHarvestTime: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
    nextHarvestTime: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000), // 5 days from now
    agnBurnRate: 90,
    ethAccumulated: 12.4,
    runwayMonths: 12
  };

  // TODO: Real contract data
  const realMetrics: AutomationMetrics = {
    aaveAPY: 0, // AaveAdapter.getCurrentAPY()
    lidoAPY: 0, // LidoAdapter.getCurrentAPY()
    totalYieldGenerated: 0,
    lastHarvestTime: new Date(0),
    nextHarvestTime: new Date(0),
    agnBurnRate: 0,
    ethAccumulated: 0,
    runwayMonths: 0
  };

  const metrics = useMockData ? mockMetrics : realMetrics;

  const formatTimeUntilNext = (nextTime: Date) => {
    const now = new Date();
    const diff = nextTime.getTime() - now.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    
    if (days > 0) return `${days}d ${hours}h`;
    return `${hours}h`;
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Automation Performance</h2>
          <p className="text-base-content/70">80/20 Automated Flywheel Metrics</p>
        </div>
        
        {/* Timeframe Selector */}
        <div className="flex bg-base-200 rounded-lg p-1">
          {["1W", "1M", "3M"].map((period) => (
            <button
              key={period}
              className={`px-3 py-1 rounded text-sm font-medium transition-colors ${
                selectedTimeframe === period
                  ? "bg-primary text-primary-content"
                  : "text-base-content/70 hover:text-base-content"
              }`}
              onClick={() => setSelectedTimeframe(period as any)}
            >
              {period}
            </button>
          ))}
        </div>
      </div>

      {/* Key Metrics Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Aave Yield */}
        <div className="bg-base-100 rounded-xl p-4 shadow-sm">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-base-content/70">Aave APY</span>
            <div className="w-2 h-2 bg-success rounded-full"></div>
          </div>
          <div className="text-2xl font-bold text-success">{metrics.aaveAPY}%</div>
          <div className="text-xs text-base-content/60">80% allocation</div>
        </div>

        {/* Lido Staking */}
        <div className="bg-base-100 rounded-xl p-4 shadow-sm">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-base-content/70">Lido APY</span>
            <div className="w-2 h-2 bg-info rounded-full"></div>
          </div>
          <div className="text-2xl font-bold text-info">{metrics.lidoAPY}%</div>
          <div className="text-xs text-base-content/60">10% allocation</div>
        </div>

        {/* AGN Burn Rate */}
        <div className="bg-base-100 rounded-xl p-4 shadow-sm">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-base-content/70">AGN Burns</span>
            <div className="w-2 h-2 bg-error rounded-full"></div>
          </div>
          <div className="text-2xl font-bold text-error">{metrics.agnBurnRate}%</div>
          <div className="text-xs text-base-content/60">10% allocation</div>
        </div>

        {/* Next Harvest */}
        <div className="bg-base-100 rounded-xl p-4 shadow-sm">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-base-content/70">Next Harvest</span>
            <div className="w-2 h-2 bg-warning rounded-full animate-pulse"></div>
          </div>
          <div className="text-2xl font-bold text-warning">{formatTimeUntilNext(metrics.nextHarvestTime)}</div>
          <div className="text-xs text-base-content/60">Automated</div>
        </div>
      </div>

      {/* Automation Status */}
      <div className="bg-base-100 rounded-xl p-6 shadow-sm">
        <h3 className="text-lg font-semibold mb-4">Automation Status</h3>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Stable Allocation */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium">Stable Allocation (80%)</span>
              <span className="text-sm text-success">Active</span>
            </div>
            <div className="w-full bg-base-200 rounded-full h-2">
              <div className="bg-success h-2 rounded-full" style={{ width: "80%" }}></div>
            </div>
            <div className="text-xs text-base-content/60 mt-1">
              Buffer + Aave compounding
            </div>
          </div>

          {/* ETH DCA */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium">ETH DCA (10%)</span>
              <span className="text-sm text-info">Active</span>
            </div>
            <div className="w-full bg-base-200 rounded-full h-2">
              <div className="bg-info h-2 rounded-full" style={{ width: "10%" }}></div>
            </div>
            <div className="text-xs text-base-content/60 mt-1">
              Weekly + Lido staking
            </div>
          </div>

          {/* AGN Buybacks */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium">AGN Buybacks (10%)</span>
              <span className="text-sm text-error">Active</span>
            </div>
            <div className="w-full bg-base-200 rounded-full h-2">
              <div className="bg-error h-2 rounded-full" style={{ width: "10%" }}></div>
            </div>
            <div className="text-xs text-base-content/60 mt-1">
              90% burn, 10% LP
            </div>
          </div>
        </div>
      </div>

      {/* Performance Summary */}
      <div className="bg-base-100 rounded-xl p-6 shadow-sm">
        <h3 className="text-lg font-semibold mb-4">Performance Summary</h3>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="text-center">
            <div className="text-2xl font-bold text-success">${metrics.totalYieldGenerated.toLocaleString()}</div>
            <div className="text-sm text-base-content/70">Total Yield Generated</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-warning">{metrics.ethAccumulated} ETH</div>
            <div className="text-sm text-base-content/70">ETH Accumulated</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-info">{metrics.runwayMonths}m</div>
            <div className="text-sm text-base-content/70">Runway Remaining</div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AutomationPerformance;
