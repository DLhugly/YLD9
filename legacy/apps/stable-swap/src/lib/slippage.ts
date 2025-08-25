import { applyBps } from "./math";

export type QuoteResult = {
  venue: "univ3" | "aerodrome";
  amountOut: bigint;
  poolFeeBps: number;
  spreadBps: number;
};

export const modelSlipBps = (_: QuoteResult): number => {
  // Simple placeholder: refined later to use pool/liquidity probes.
  return 30;
};

export const minOutFrom = (amountOut: bigint, slipBps: number): bigint => applyBps(amountOut, slipBps);



