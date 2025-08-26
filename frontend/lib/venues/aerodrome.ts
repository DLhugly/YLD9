import { Address } from "viem";
import { publicClient } from "../viem";
import { AERODROME_ROUTER } from "../config";

// Solidly-style router minimal ABI
const AERO_ROUTER_ABI = [
  {
    type: "function",
    name: "getAmountsOut",
    stateMutability: "view",
    inputs: [
      { name: "amountIn", type: "uint256" },
      { name: "routes", type: "tuple[]", components: [
        { name: "from", type: "address" },
        { name: "to", type: "address" },
        { name: "stable", type: "bool" }
      ]}
    ],
    outputs: [{ name: "amounts", type: "uint256[]" }]
  },
];

export type AeroQuote = {
  venue: "aerodrome";
  router: Address;
  calldata: `0x${string}`;
  amountOut: bigint;
  poolFeeBps: number;
  spreadBps: number;
};

export async function quoteAero(tokenIn: Address, tokenOut: Address, amountIn: bigint): Promise<AeroQuote | null> {
  // Prefer stable route
  const route = [{ from: tokenIn, to: tokenOut, stable: true }];
  try {
    const amounts = await publicClient.readContract({
      address: AERODROME_ROUTER,
      abi: AERO_ROUTER_ABI,
      functionName: "getAmountsOut",
      args: [amountIn, route],
    }) as bigint[];
    const amountOut = amounts[amounts.length - 1];
    if (!amountOut || amountOut === 0n) return null;

    // For calldata, Solidly router uses swapExactTokensForTokensSupportingFeeOnTransferTokens or similar; we prepare off-chain later.
    const calldata = "0x" as `0x${string}`;
    return {
      venue: "aerodrome",
      router: AERODROME_ROUTER,
      calldata,
      amountOut,
      poolFeeBps: 1, // typical ~1bp stable; verify per-pool if needed
      spreadBps: 0,
    };
  } catch {
    return null;
  }
}



