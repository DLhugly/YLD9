import { createPublicClient, createWalletClient, http } from "viem";
import { base } from "viem/chains";

if (!process.env.RPC_URL_BASE) {
  throw new Error("RPC_URL_BASE is required");
}

export const publicClient = createPublicClient({
  chain: base,
  transport: http(process.env.RPC_URL_BASE),
});

export const getWalletClient = async () => {
  const client = createWalletClient({ chain: base, transport: http(process.env.RPC_URL_BASE!) });
  return client;
};



