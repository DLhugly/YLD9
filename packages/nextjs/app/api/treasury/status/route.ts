import { NextRequest, NextResponse } from "next/server";
import { createPublicClient, http } from "viem";
import { base } from "viem/chains";

/**
 * API route for treasury status including ETH holdings, safety gates, and DCA history
 * GET /api/treasury/status
 */

// Create Base L2 client
const publicClient = createPublicClient({
  chain: base,
  transport: http()
});

// Mock treasury data - in production this would come from smart contracts
const getTreasuryData = async () => {
  return {
    ethHoldings: {
      liquid: 45.2,
      staked: 12.8,
      rewards: 0.6,
      total: 58.6
    },
    stablecoinHoldings: {
      usdc: 125000,
      usd1: 85000,
      eurc: 65000,
      total: 275000
    },
    safetyGates: {
      runway: {
        months: 8.2,
        status: "green",
        threshold: 6.0
      },
      coverageRatio: {
        ratio: 1.45,
        status: "green", 
        threshold: 1.2
      },
      buybacksEnabled: true
    },
    dcaHistory: [
      {
        date: "2024-08-18",
        usdcAmount: 5000,
        ethAmount: 1.67,
        ethPrice: 2995,
        txHash: "0x1234...5678"
      },
      {
        date: "2024-08-11", 
        usdcAmount: 5000,
        ethAmount: 1.72,
        ethPrice: 2907,
        txHash: "0x2345...6789"
      },
      {
        date: "2024-08-04",
        usdcAmount: 5000,
        ethAmount: 1.61,
        ethPrice: 3106,
        txHash: "0x3456...7890"
      }
    ],
    stakingRewards: {
      apr: 4.2,
      totalEarned: 2.1,
      lastClaim: "2024-08-15",
      provider: "Lido"
    }
  };
};

// Calculate treasury metrics
const calculateMetrics = (treasuryData: any) => {
  const { ethHoldings, stablecoinHoldings, dcaHistory } = treasuryData;
  
  // Calculate current ETH price (mock)
  const currentETHPrice = 3050;
  
  // Total treasury value in USD
  const ethValue = ethHoldings.total * currentETHPrice;
  const totalValue = ethValue + stablecoinHoldings.total;
  
  // DCA performance metrics
  const totalDCASpent = dcaHistory.reduce((sum: number, tx: any) => sum + tx.usdcAmount, 0);
  const totalETHBought = dcaHistory.reduce((sum: number, tx: any) => sum + tx.ethAmount, 0);
  const averageBuyPrice = totalDCASpent / totalETHBought;
  const dcaPerformance = ((currentETHPrice - averageBuyPrice) / averageBuyPrice) * 100;
  
  return {
    totalValue,
    ethValue,
    ethAllocation: (ethValue / totalValue) * 100,
    dca: {
      totalSpent: totalDCASpent,
      totalETHBought,
      averageBuyPrice,
      performance: dcaPerformance,
      currentPrice: currentETHPrice
    }
  };
};

export async function GET(request: NextRequest) {
  try {
    // Get treasury data
    const treasuryData = await getTreasuryData();
    
    // Calculate metrics
    const metrics = calculateMetrics(treasuryData);
    
    // Combine response
    const response = {
      ...treasuryData,
      metrics,
      metadata: {
        timestamp: new Date().toISOString(),
        updateFrequency: "1 minute",
        network: "Base L2"
      },
      parameters: {
        monthlyOpex: 50000, // $50k
        weeklyDCACap: 5000, // $5k
        fxArbThreshold: 0.1, // 0.1%
        ethStakingLimit: 20 // 20%
      }
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error("Error fetching treasury status:", error);
    return NextResponse.json(
      { error: "Failed to fetch treasury status" },
      { status: 500 }
    );
  }
}
