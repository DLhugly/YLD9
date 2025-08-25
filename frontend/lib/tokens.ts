export type TokenMeta = {
  symbol: "USDC" | "EURC" | "USD1";
  name: string;
  address: `0x${string}`;
  decimals: number;
};

// Addresses must be provided via env or hardcoded once verified. No placeholders.
const getAddress = (key: string): `0x${string}` => {
  const v = process.env[key];
  if (!v || !v.startsWith("0x")) throw new Error(`${key} missing or invalid`);
  return v as `0x${string}`;
};

const getInt = (key: string): number => {
  const v = process.env[key];
  if (!v) throw new Error(`${key} missing`);
  const n = Number(v);
  if (!Number.isInteger(n)) throw new Error(`${key} must be integer`);
  return n;
};

export const TOKENS: Record<TokenMeta["symbol"], TokenMeta> = {
  USDC: {
    symbol: "USDC",
    name: "USD Coin",
    address: getAddress("USDC_ADDR"),
    decimals: getInt("USDC_DECIMALS"),
  },
  EURC: {
    symbol: "EURC",
    name: "Euro Coin",
    address: getAddress("EURC_ADDR"),
    decimals: getInt("EURC_DECIMALS"),
  },
  USD1: {
    symbol: "USD1",
    name: "USD1 Stablecoin",
    address: getAddress("USD1_ADDR"),
    decimals: getInt("USD1_DECIMALS"),
  },
};

export const bySymbol = (s: TokenMeta["symbol"]): TokenMeta => TOKENS[s];



