import { NextRequest, NextResponse } from "next/server";
import { quoteUni } from "@/lib/venues/univ3";
import { quoteAero } from "@/lib/venues/aerodrome";
import { modelSlipBps, minOutFrom } from "@/lib/slippage";
import { ROUTER_FEE_BPS, SAFETY_BUFFER_BPS } from "@/lib/config";

export async function POST(req: NextRequest) {
  try {
    const { tokenIn, tokenOut, amountIn } = await req.json();
    if (!tokenIn || !tokenOut || !amountIn) return NextResponse.json({ error: "BAD_REQ" }, { status: 400 });
    const amt: bigint = BigInt(amountIn);

    const [u, a] = await Promise.all([
      quoteUni(tokenIn, tokenOut, amt),
      quoteAero(tokenIn, tokenOut, amt),
    ]);

    const routes = [u, a].filter(Boolean) as Array<ReturnTypeNonNullable<typeof quoteUni> | ReturnTypeNonNullable<typeof quoteAero>>;
    if (routes.length === 0) return NextResponse.json({ error: "NO_ROUTE" }, { status: 400 });

    const ranked = routes.map((r: any) => {
      const slip = modelSlipBps({ venue: r.venue, amountOut: r.amountOut, poolFeeBps: r.poolFeeBps, spreadBps: 0 });
      const netBps = (r.spreadBps ?? 0) - r.poolFeeBps - slip - SAFETY_BUFFER_BPS - ROUTER_FEE_BPS;
      return { ...r, slipBps: slip, netBps, minOut: minOutFrom(r.amountOut, slip) };
    }).sort((x, y) => Number(y.amountOut - x.amountOut));

    return NextResponse.json(ranked[0]);
  } catch (e: any) {
    return NextResponse.json({ error: e?.message ?? "ERR" }, { status: 500 });
  }
}

type ReturnTypeNonNullable<T> = T extends (...args: any) => infer R ? NonNullable<R> : never;



