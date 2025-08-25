const reqNum = (key: string): number => {
  const v = process.env[key];
  if (!v) throw new Error(`${key} missing`);
  const n = Number(v);
  if (!Number.isFinite(n)) throw new Error(`${key} invalid number`);
  return n;
};

const reqAddr = (key: string): `0x${string}` => {
  const v = process.env[key];
  if (!v || !v.startsWith("0x")) throw new Error(`${key} missing/invalid`);
  return v as `0x${string}`;
};

export const CHAIN_ID_BASE = Number(process.env.CHAIN_ID_BASE ?? 8453);

export const ROUTER_FEE_BPS = reqNum("ROUTER_FEE_BPS");
export const DEFAULT_SLIPPAGE_BPS = reqNum("DEFAULT_SLIPPAGE_BPS");
export const SAFETY_BUFFER_BPS = reqNum("SAFETY_BUFFER_BPS");
export const MAX_GAS_USD = Number(process.env.MAX_GAS_USD ?? 0.25);

export const UNIV3_UNIVERSAL_ROUTER = reqAddr("UNIV3_UNIVERSAL_ROUTER");
export const UNIV3_QUOTER_V2 = reqAddr("UNIV3_QUOTER_V2");
export const AERODROME_ROUTER = reqAddr("AERODROME_ROUTER");

export const CHAINLINK_EURUSD_FEED = reqAddr("CHAINLINK_EURUSD_FEED");
export const PYTH_EURUSD_ID = process.env.PYTH_EURUSD_ID as `0x${string}`;
export const PYTH_ENDPOINT = reqAddr("PYTH_ENDPOINT");



