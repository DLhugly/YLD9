import { NextRequest, NextResponse } from "next/server";
import { quoteUni } from "@/lib/venues/univ3";
import { quoteAero } from "@/lib/venues/aerodrome";
import { CHAINLINK_EURUSD_FEED, PYTH_EURUSD_ID, PYTH_ENDPOINT } from "@/lib/config";
import { publicClient } from "@/lib/viem";

const CHAINLINK_ABI = [
  { type: "function", name: "latestRoundData", stateMutability: "view", inputs: [], outputs: [
    { name: "roundId", type: "uint80" },
    { name: "answer", type: "int256" },
    { name: "startedAt", type: "uint256" },
    { name: "updatedAt", type: "uint256" },
    { name: "answeredInRound", type: "uint80" },
  ] },
  { type: "function", name: "decimals", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint8" }]},
];

const PYTH_ABI = [
  { type: "function", name: "getPriceUnsafe", stateMutability: "view", inputs: [{ name: "id", type: "bytes32" }], outputs: [
    { name: "price", type: "int64" },
    { name: "conf", type: "uint64" },
    { name: "expo", type: "int32" },
    { name: "publishTime", type: "uint64" },
  ]},
];

export async function POST(req: NextRequest) {
  try {
    const { tokenIn, tokenOut, amountIn } = await req.json();
    const amt: bigint = BigInt(amountIn);

    const [u, a] = await Promise.all([
      quoteUni(tokenIn, tokenOut, amt),
      quoteAero(tokenIn, tokenOut, amt),
    ]);
    const best = [u, a].filter(Boolean).sort((x: any, y: any) => Number((y as any).amountOut - (x as any).amountOut))[0] as any;
    if (!best) return NextResponse.json({ error: "NO_ROUTE" }, { status: 400 });

    const [clDec, clData, pyth] = await Promise.all([
      publicClient.readContract({ address: CHAINLINK_EURUSD_FEED, abi: CHAINLINK_ABI as const, functionName: "decimals", args: [] }) as Promise<number>,
      publicClient.readContract({ address: CHAINLINK_EURUSD_FEED, abi: CHAINLINK_ABI as const, functionName: "latestRoundData", args: [] }) as Promise<any>,
      publicClient.readContract({ address: PYTH_ENDPOINT, abi: PYTH_ABI as const, functionName: "getPriceUnsafe", args: [PYTH_EURUSD_ID] }) as Promise<any>,
    ]);

    const clPrice = Number(clData[1]) / 10 ** clDec;
    const pythPrice = Number(pyth[0]) * 10 ** Number(pyth[2]); // price * 10^expo (expo negative)
    const median = [clPrice, pythPrice].sort((x, y) => x - y)[1 - 0]; // median of two = upper of sorted pair

    // implied FX from amountOut/amountIn; assume both 6 decimals at this stage; frontend will normalize by actual decimals.
    const implied = Number(best.amountOut) / Number(amt);
    const deltaBps = ((implied / median) - 1) * 10_000;

    return NextResponse.json({ implied, oracle: median, deltaBps, venue: best.venue, router: best.router, calldata: best.calldata, amountOut: best.amountOut });
  } catch (e: any) {
    return NextResponse.json({ error: e?.message ?? "ERR" }, { status: 500 });
  }
}



