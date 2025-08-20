"use client";
import { useState } from "react";
import { Address } from "viem";

type RouteResp = {
  venue: "univ3" | "aerodrome";
  router: Address;
  calldata: `0x${string}`;
  amountOut: string | number | bigint;
  minOut: string | number | bigint;
  slipBps: number;
  netBps: number;
};

export function SwapCard() {
  const [tokenIn, setTokenIn] = useState<Address>("0x0000000000000000000000000000000000000000");
  const [tokenOut, setTokenOut] = useState<Address>("0x0000000000000000000000000000000000000000");
  const [amountIn, setAmountIn] = useState<string>("0");
  const [route, setRoute] = useState<RouteResp | null>(null);

  const getRoute = async () => {
    const r = await fetch("/api/quote/route", { method: "POST", body: JSON.stringify({ tokenIn, tokenOut, amountIn }) });
    const j = await r.json();
    setRoute(j);
  };

  return (
    <div className="rounded-lg border p-4 space-y-3">
      <div className="text-lg font-semibold">Swap</div>
      <input className="w-full border p-2 rounded" placeholder="tokenIn" value={tokenIn} onChange={e=>setTokenIn(e.target.value as Address)} />
      <input className="w-full border p-2 rounded" placeholder="tokenOut" value={tokenOut} onChange={e=>setTokenOut(e.target.value as Address)} />
      <input className="w-full border p-2 rounded" placeholder="amountIn (wei)" value={amountIn} onChange={e=>setAmountIn(e.target.value)} />
      <button className="w-full bg-blue-600 text-white p-2 rounded" onClick={getRoute}>Quote</button>
      {route && (
        <div className="text-sm">
          <div>venue: {route.venue}</div>
          <div>amountOut: {String(route.amountOut)}</div>
          <div>minOut: {String(route.minOut)}</div>
          <div>netBps: {route.netBps}</div>
        </div>
      )}
    </div>
  );
}

export default SwapCard;



