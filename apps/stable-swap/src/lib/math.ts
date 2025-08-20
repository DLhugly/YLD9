export const bpsToRatio = (bps: number): number => bps / 10_000;
export const ratioToBps = (r: number): number => Math.round(r * 10_000);
export const applyBps = (x: bigint, bps: number): bigint => (x * BigInt(10_000 - bps)) / 10_000n;
export const addBps = (x: bigint, bps: number): bigint => (x * BigInt(10_000 + bps)) / 10_000n;

export const toDecimal = (x: bigint, decimals: number): number => Number(x) / 10 ** decimals;
export const fromDecimal = (x: number, decimals: number): bigint => BigInt(Math.floor(x * 10 ** decimals));



