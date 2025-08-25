"use client";

import { useState, useEffect } from "react";
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { formatEther, parseEther } from "viem";
import { EtherInput } from "./scaffold-eth/Input";
import { Address } from "./scaffold-eth/Address";
import { useTargetNetwork } from "~~/hooks/scaffold-eth";

/**
 * VaultCard component - Multi-stablecoin vault interface with yield simulator
 * Based on UI_FRONTEND.md "ETH Treasury Fortress" theme
 */
export const VaultCard = () => {
  const { address: connectedAddress } = useAccount();
  const { targetNetwork } = useTargetNetwork();

  // State management
  const [selectedAsset, setSelectedAsset] = useState<"USDC" | "USD1" | "EURC">("USDC");
  const [depositAmount, setDepositAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [isDepositing, setIsDepositing] = useState(true);
  const [ethBoostPercentage, setEthBoostPercentage] = useState(0);

  // Supported stablecoins on Base L2
  const supportedAssets = {
    USDC: {
      address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      symbol: "USDC",
      name: "USD Coin",
      decimals: 6,
      icon: "💵"
    },
    USD1: {
      address: "0x0000000000000000000000000000000000000001", // Placeholder
      symbol: "USD1", 
      name: "USD1 Stablecoin",
      decimals: 18,
      icon: "🪙"
    },
    EURC: {
      address: "0x0000000000000000000000000000000000000002", // Placeholder
      symbol: "EURC",
      name: "Euro Coin", 
      decimals: 6,
      icon: "💶"
    }
  };

  // Mock vault contract address (would be deployed contract)
  const VAULT_ADDRESS = "0x0000000000000000000000000000000000000000";

  // Read vault data (mock for now)
  const { data: totalAssets } = useReadContract({
    address: VAULT_ADDRESS,
    abi: [
      {
        name: "totalAssets",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [{ type: "uint256" }]
      }
    ],
    functionName: "totalAssets"
  });

  const { data: userShares } = useReadContract({
    address: VAULT_ADDRESS,
    abi: [
      {
        name: "balanceOf", 
        type: "function",
        stateMutability: "view",
        inputs: [{ type: "address" }],
        outputs: [{ type: "uint256" }]
      }
    ],
    functionName: "balanceOf",
    args: [connectedAddress]
  });

  // Write contract hooks
  const { writeContract: deposit } = useWriteContract();
  const { writeContract: withdraw } = useWriteContract();

  // Yield simulator calculations
  const calculateProjectedYield = () => {
    if (!depositAmount || isNaN(Number(depositAmount))) return { monthly: 0, ethGain: 0 };
    
    const amount = Number(depositAmount);
    const baseAPY = 0.05; // 5% base APY
    const monthlyYield = (amount * baseAPY) / 12;
    const ethGain = (monthlyYield * ethBoostPercentage) / 100;
    
    return {
      monthly: monthlyYield,
      ethGain: ethGain,
      stablecoinYield: monthlyYield - ethGain
    };
  };

  const projectedYield = calculateProjectedYield();

  const handleDeposit = async () => {
    if (!depositAmount || !connectedAddress) return;
    
    try {
      // In production: call actual vault deposit function
      console.log(`Depositing ${depositAmount} ${selectedAsset}`);
      
      // Mock deposit call
      deposit({
        address: VAULT_ADDRESS,
        abi: [
          {
            name: "deposit",
            type: "function", 
            stateMutability: "nonpayable",
            inputs: [
              { name: "assets", type: "uint256" },
              { name: "receiver", type: "address" }
            ],
            outputs: [{ type: "uint256" }]
          }
        ],
        functionName: "deposit",
        args: [parseEther(depositAmount), connectedAddress]
      });
    } catch (error) {
      console.error("Deposit failed:", error);
    }
  };

  const handleWithdraw = async () => {
    if (!withdrawAmount || !connectedAddress) return;
    
    try {
      // In production: call actual vault withdraw function
      console.log(`Withdrawing ${withdrawAmount} shares to ${selectedAsset}`);
      
      // Mock withdraw call
      withdraw({
        address: VAULT_ADDRESS,
        abi: [
          {
            name: "withdrawToAsset",
            type: "function",
            stateMutability: "nonpayable", 
            inputs: [
              { name: "shares", type: "uint256" },
              { name: "asset", type: "address" },
              { name: "receiver", type: "address" }
            ],
            outputs: [{ type: "uint256" }]
          }
        ],
        functionName: "withdrawToAsset",
        args: [parseEther(withdrawAmount), supportedAssets[selectedAsset].address, connectedAddress]
      });
    } catch (error) {
      console.error("Withdraw failed:", error);
    }
  };

  return (
    <div className="bg-base-100 border-base-300 border shadow-md shadow-secondary rounded-3xl px-6 py-8 w-full max-w-lg mx-auto">
      {/* Header */}
      <div className="flex flex-col items-center mb-6">
        <div className="text-4xl mb-2">🏦</div>
        <h2 className="text-2xl font-bold text-center">Agonic Vault</h2>
        <p className="text-sm text-base-content/70 text-center">Multi-Stablecoin Yield with ETH Treasury</p>
      </div>

      {/* Mode Toggle */}
      <div className="flex bg-base-200 rounded-2xl p-1 mb-6">
        <button
          className={`flex-1 py-2 px-4 rounded-xl font-medium transition-all ${
            isDepositing 
              ? "bg-primary text-primary-content shadow-sm" 
              : "text-base-content/70 hover:text-base-content"
          }`}
          onClick={() => setIsDepositing(true)}
        >
          Deposit
        </button>
        <button
          className={`flex-1 py-2 px-4 rounded-xl font-medium transition-all ${
            !isDepositing 
              ? "bg-primary text-primary-content shadow-sm" 
              : "text-base-content/70 hover:text-base-content"
          }`}
          onClick={() => setIsDepositing(false)}
        >
          Withdraw
        </button>
      </div>

      {/* Asset Selector */}
      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">Asset</label>
        <div className="grid grid-cols-3 gap-2">
          {Object.entries(supportedAssets).map(([key, asset]) => (
            <button
              key={key}
              className={`p-3 rounded-xl border transition-all ${
                selectedAsset === key
                  ? "border-primary bg-primary/10 text-primary"
                  : "border-base-300 hover:border-base-content/30"
              }`}
              onClick={() => setSelectedAsset(key as keyof typeof supportedAssets)}
            >
              <div className="text-lg mb-1">{asset.icon}</div>
              <div className="text-xs font-medium">{asset.symbol}</div>
            </button>
          ))}
        </div>
      </div>

      {isDepositing ? (
        <>
          {/* Deposit Amount Input */}
          <div className="mb-4">
            <label className="block text-sm font-medium mb-2">Amount</label>
            <div className="relative">
              <input
                type="number"
                placeholder="0.00"
                className="input input-bordered w-full pr-16"
                value={depositAmount}
                onChange={(e) => setDepositAmount(e.target.value)}
              />
              <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-sm font-medium text-base-content/70">
                {supportedAssets[selectedAsset].symbol}
              </div>
            </div>
          </div>

          {/* ETH Boost Slider */}
          <div className="mb-6">
            <label className="block text-sm font-medium mb-2">
              ETH Boost: {ethBoostPercentage}% of yield
            </label>
            <input
              type="range"
              min="0"
              max="50"
              value={ethBoostPercentage}
              onChange={(e) => setEthBoostPercentage(Number(e.target.value))}
              className="range range-primary w-full"
            />
            <div className="flex justify-between text-xs text-base-content/50 mt-1">
              <span>0%</span>
              <span>25%</span>
              <span>50%</span>
            </div>
          </div>

          {/* Yield Simulator */}
          {depositAmount && Number(depositAmount) > 0 && (
            <div className="bg-base-200 rounded-2xl p-4 mb-6">
              <h3 className="font-medium mb-3 flex items-center">
                <span className="text-lg mr-2">📊</span>
                Projected Monthly Yield
              </h3>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span>Total Yield:</span>
                  <span className="font-medium">${projectedYield.monthly.toFixed(2)}</span>
                </div>
                {ethBoostPercentage > 0 && (
                  <>
                    <div className="flex justify-between text-warning">
                      <span>ETH Portion:</span>
                      <span className="font-medium">${projectedYield.ethGain.toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span>{selectedAsset} Portion:</span>
                      <span className="font-medium">${projectedYield.stablecoinYield?.toFixed(2)}</span>
                    </div>
                  </>
                )}
                <div className="border-t pt-2 mt-2">
                  <div className="flex justify-between text-xs text-base-content/70">
                    <span>Base APY: ~5%</span>
                    <span>Updated real-time</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Deposit Button */}
          <button
            className="btn btn-primary w-full"
            onClick={handleDeposit}
            disabled={!depositAmount || !connectedAddress}
          >
            {!connectedAddress ? "Connect Wallet" : `Deposit ${selectedAsset}`}
          </button>
        </>
      ) : (
        <>
          {/* User Position Info */}
          <div className="bg-base-200 rounded-2xl p-4 mb-4">
            <h3 className="font-medium mb-2">Your Position</h3>
            <div className="space-y-1 text-sm">
              <div className="flex justify-between">
                <span>Vault Shares:</span>
                <span className="font-medium">
                  {userShares ? formatEther(userShares) : "0.00"}
                </span>
              </div>
              <div className="flex justify-between">
                <span>Est. Value:</span>
                <span className="font-medium">$0.00</span>
              </div>
            </div>
          </div>

          {/* Withdraw Amount Input */}
          <div className="mb-4">
            <label className="block text-sm font-medium mb-2">Shares to Withdraw</label>
            <div className="relative">
              <input
                type="number"
                placeholder="0.00"
                className="input input-bordered w-full pr-20"
                value={withdrawAmount}
                onChange={(e) => setWithdrawAmount(e.target.value)}
              />
              <button 
                className="absolute right-3 top-1/2 transform -translate-y-1/2 text-xs btn btn-ghost btn-xs"
                onClick={() => setWithdrawAmount(userShares ? formatEther(userShares) : "0")}
              >
                MAX
              </button>
            </div>
          </div>

          {/* Withdraw Button */}
          <button
            className="btn btn-secondary w-full"
            onClick={handleWithdraw}
            disabled={!withdrawAmount || !connectedAddress}
          >
            {!connectedAddress ? "Connect Wallet" : `Withdraw to ${selectedAsset}`}
          </button>
        </>
      )}

      {/* Footer Stats */}
      <div className="mt-6 pt-4 border-t border-base-300">
        <div className="grid grid-cols-2 gap-4 text-center text-sm">
          <div>
            <div className="text-base-content/50">Total TVL</div>
            <div className="font-medium">
              ${totalAssets ? (Number(formatEther(totalAssets)) * 1).toLocaleString() : "0"}
            </div>
          </div>
          <div>
            <div className="text-base-content/50">Current APY</div>
            <div className="font-medium text-success">~5.2%</div>
          </div>
        </div>
      </div>
    </div>
  );
};
