import { NextRequest, NextResponse } from "next/server";
import { createPublicClient, http } from "viem";
import { base } from "viem/chains";

/**
 * API route for ultra-simple staking vault APY data
 * GET /api/vault/apy - Returns 80/20 automated flywheel APY
 */

// Create Base L2 client
const publicClient = createPublicClient({
  chain: base,
  transport: http()
});

// Ultra-simple APY calculation for 80/20 automation
const getAutomatedAPY = async () => {
  // Mock data - in production would query AaveAdapter.getCurrentAPY() and LidoAdapter.getCurrentAPY()
  const useMockData = process.env.NEXT_PUBLIC_USE_MOCK_DATA === "true";
  
  if (useMockData) {
    return {
      aave: {
        usdc: 8.2 // Realistic Aave USDC APY on Base
      },
      lido: {
        eth: 3.8 // Realistic Lido staking APY
      }
    };
  }
  
  // TODO: Real contract calls
  return {
    aave: {
      usdc: 0 // AaveAdapter.getCurrentAPY(USDC)
    },
    lido: {
      eth: 0 // LidoAdapter.getCurrentAPY()
    }
  };
};

// Calculate 80/20 automated flywheel APY
const calculateAutomatedAPY = (protocolAPYs: any) => {
  // 80/20 allocation: 80% USDC (buffer + Aave), 20% growth (ETH + buybacks)
  const stableAPY = protocolAPYs.aave.usdc; // 80% allocation
  const ethAPY = protocolAPYs.lido.eth; // 10% allocation (other 10% is buybacks)
  
  // Weighted average: 80% stable + 10% ETH (buybacks don't generate APY, they burn tokens)
  const weightedAPY = (stableAPY * 0.8) + (ethAPY * 0.1);
  
  return {
    overall: weightedAPY,
    stable: stableAPY,
    eth: ethAPY,
    allocations: {
      stableBuffer: 60, // % of total
      aaveYield: 20,    // % of total
      ethDCA: 10,       // % of total
      agnBuybacks: 10   // % of total (burns tokens)
    }
  };
};

export async function GET(request: NextRequest) {
  try {
    // Get current automated APYs
    const protocolAPYs = await getAutomatedAPY();
    
    // Calculate 80/20 automated APY
    const apyData = calculateAutomatedAPY(protocolAPYs);
    
    // Add fee adjustment (5% fee on staking yield)
    const feeAdjustedAPY = {
      ...apyData,
      overall: apyData.overall * 0.95, // 95% after 5% fee
      stable: apyData.stable * 0.95,
      eth: apyData.eth * 0.95
    };

    // Add metadata
    const response = {
      ...feeAdjustedAPY,
      metadata: {
        timestamp: new Date().toISOString(),
        feeRate: 0.05, // 5% staking fee
        updateFrequency: "Weekly via Chainlink Automation",
        source: "80/20 Automated Flywheel",
        burnRate: 0.9 // 90% of buybacks burned
      },
      automation: {
        harvestFrequency: "7 days",
        dcaFrequency: "7 days", 
        lastHarvest: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(), // 2 days ago
        nextHarvest: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString() // 5 days from now
      }
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error("Error fetching automated APY:", error);
    return NextResponse.json(
      { error: "Failed to fetch automated APY data" },
      { status: 500 }
    );
  }
}
