import { NextRequest, NextResponse } from "next/server";
import { createPublicClient, http } from "viem";
import { base } from "viem/chains";

/**
 * API route for vault APY data across multiple protocols
 * GET /api/vault/apy
 */

// Create Base L2 client
const publicClient = createPublicClient({
  chain: base,
  transport: http()
});

// Mock protocol APYs - in production these would come from actual protocol APIs
const getProtocolAPYs = async () => {
  return {
    aave: {
      usdc: 3.2,
      usd1: 3.1,
      eurc: 3.3
    },
    wlf: {
      usdc: 5.8,
      usd1: 5.9,
      eurc: 5.7
    },
    uniswapV3: {
      usdc: 7.2,
      usd1: 6.8,
      eurc: 7.5
    },
    aerodrome: {
      usdc: 6.9,
      usd1: 7.1,
      eurc: 6.7
    }
  };
};

// Calculate weighted average APY based on allocation caps
const calculateWeightedAPY = (protocolAPYs: any) => {
  // Allocation caps from roadmap: Aave ≤60%, WLF ≤40%, LP strategies ≤30% each
  const allocations = {
    aave: 0.4,      // 40% allocation to Aave (conservative)
    wlf: 0.25,      // 25% to WLF
    uniswapV3: 0.2, // 20% to Uniswap V3
    aerodrome: 0.15 // 15% to Aerodrome
  };

  const assets = ['usdc', 'usd1', 'eurc'];
  const weightedAPYs: any = {};

  assets.forEach(asset => {
    let weightedSum = 0;
    let totalWeight = 0;

    Object.entries(allocations).forEach(([protocol, weight]) => {
      if (protocolAPYs[protocol] && protocolAPYs[protocol][asset]) {
        weightedSum += protocolAPYs[protocol][asset] * weight;
        totalWeight += weight;
      }
    });

    weightedAPYs[asset] = totalWeight > 0 ? weightedSum / totalWeight : 0;
  });

  // Calculate overall weighted APY (assuming equal asset distribution for now)
  const overallAPY = (weightedAPYs.usdc + weightedAPYs.usd1 + weightedAPYs.eurc) / 3;

  return {
    overall: overallAPY,
    byAsset: weightedAPYs,
    byProtocol: protocolAPYs,
    allocations
  };
};

export async function GET(request: NextRequest) {
  try {
    // Get current protocol APYs
    const protocolAPYs = await getProtocolAPYs();
    
    // Calculate weighted APY
    const apyData = calculateWeightedAPY(protocolAPYs);
    
    // Add fee adjustment (12% fee on yield)
    const feeAdjustedAPY = {
      ...apyData,
      overall: apyData.overall * 0.88, // 88% after 12% fee
      byAsset: {
        usdc: apyData.byAsset.usdc * 0.88,
        usd1: apyData.byAsset.usd1 * 0.88,
        eurc: apyData.byAsset.eurc * 0.88
      }
    };

    // Add metadata
    const response = {
      ...feeAdjustedAPY,
      metadata: {
        timestamp: new Date().toISOString(),
        feeRate: 0.12, // 12%
        updateFrequency: "5 minutes",
        source: "Multi-protocol aggregation"
      },
      protocolLimits: {
        aave: { max: 60, current: 40 },
        wlf: { max: 40, current: 25 },
        uniswapV3: { max: 30, current: 20 },
        aerodrome: { max: 30, current: 15 }
      }
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error("Error fetching vault APY:", error);
    return NextResponse.json(
      { error: "Failed to fetch vault APY data" },
      { status: 500 }
    );
  }
}
