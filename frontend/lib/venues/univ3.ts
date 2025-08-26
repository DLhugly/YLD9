import { Address, encodeAbiParameters, encodePacked, zeroAddress } from "viem";
import { publicClient } from "../viem";
import { UNIV3_QUOTER_V2, UNIV3_UNIVERSAL_ROUTER } from "../config";

// Minimal ABIs
const QUOTER_V2_ABI = [
  {
    type: "function",
    name: "quoteExactInputSingle",
    stateMutability: "view",
    inputs: [
      { name: "params", type: "tuple", components: [
        { name: "tokenIn", type: "address" },
        { name: "tokenOut", type: "address" },
        { name: "fee", type: "uint24" },
        { name: "amountIn", type: "uint256" },
        { name: "sqrtPriceLimitX96", type: "uint160" }
      ]}
    ],
    outputs: [{ name: "amountOut", type: "uint256" }]
  },
];

export type UniQuote = {
  venue: "univ3";
  router: Address;
  calldata: `0x${string}`;
  amountOut: bigint;
  poolFeeBps: number;
  spreadBps: number;
};

const FEE_1BP = 100n; // 0.01% = 1 bp in Uniswap is 100 in uint24 (100 = 0.01%)
const FEE_5BP = 500n; // 0.05%

export async function quoteUni(tokenIn: Address, tokenOut: Address, amountIn: bigint): Promise<UniQuote | null> {
  const tryFee = async (fee: bigint) => {
    try {
      const amountOut = await publicClient.readContract({
        address: UNIV3_QUOTER_V2,
        abi: QUOTER_V2_ABI,
        functionName: "quoteExactInputSingle",
        args: [{ tokenIn, tokenOut, fee, amountIn, sqrtPriceLimitX96: 0n }],
      }) as bigint;
      return amountOut;
    } catch {
      return 0n;
    }
  };

  const direct01 = await tryFee(FEE_1BP);
  const direct05 = direct01 === 0n ? await tryFee(FEE_5BP) : 0n;
  const amountOut = direct01 > 0n ? direct01 : direct05;
  if (amountOut === 0n) return null;

  const feeTier = direct01 > 0n ? 100 : 500; // in bps terms for reporting
  const poolFeeBps = feeTier; // equal to bps

  // Build path for UR V3_SWAP_EXACT_IN: path = tokenIn(20) | fee(3) | tokenOut(20)
  const path = encodePacked(["address", "uint24", "address"], [tokenIn, feeTier as unknown as number, tokenOut]);

  // Universal Router calldata: we use single V3 swap exact in command (0x00) with inputs: recipient, amountIn, amountOutMin, path, payerIsUser
  // For server quote, we leave minOut to be filled on frontend with modeled slippage; set to 0 here
  const command = "0x00"; // V3_SWAP_EXACT_IN
  const inputs = encodeAbiParameters(
    [
      { name: "recipient", type: "address" },
      { name: "amountIn", type: "uint256" },
      { name: "amountOutMin", type: "uint256" },
      { name: "path", type: "bytes" },
      { name: "payerIsUser", type: "bool" },
    ],
    [zeroAddress, amountIn, 0n, path, true]
  );
  const calldata = (command + inputs.slice(2)) as `0x${string}`;

  return {
    venue: "univ3",
    router: UNIV3_UNIVERSAL_ROUTER,
    calldata,
    amountOut,
    poolFeeBps,
    spreadBps: 0, // same-asset stable pairs, spread modeled separately
  };
}



