"use client";

import { useState, useEffect } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { formatUnits, parseUnits, formatEther, parseEther } from "viem";
import { useTargetNetwork } from "~~/hooks/scaffold-eth";
import { notification } from "~~/utils/scaffold-eth";

/**
 * StakingVaultCard component - USDC/ETH staking with AGN boosts
 * Based on StakingVault.sol contract
 */
export const StakingVaultCard = () => {
  const { address: connectedAddress } = useAccount();
  const { targetNetwork } = useTargetNetwork();

  // State management
  const [selectedAsset, setSelectedAsset] = useState<"USDC" | "ETH">("USDC");
  const [stakeAmount, setStakeAmount] = useState("");
  const [withdrawShares, setWithdrawShares] = useState("");
  const [isStaking, setIsStaking] = useState(true);
  const [lockAmount, setLockAmount] = useState("");
  const [lockDuration, setLockDuration] = useState(90); // days

  // Contract addresses (would be from deployedContracts.ts)
  const STAKING_VAULT_ADDRESS = "0x0000000000000000000000000000000000000000"; // Placeholder
  const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"; // Base USDC
  const WETH_ADDRESS = "0x4200000000000000000000000000000000000006"; // Base WETH
  const AGN_ADDRESS = "0x0000000000000000000000000000000000000000"; // Placeholder

  // Asset configuration
  const assets = {
    USDC: {
      address: USDC_ADDRESS,
      symbol: "USDC",
      name: "USD Coin",
      decimals: 6,
      icon: "💵",
      expectedAPY: "8-12%"
    },
    ETH: {
      address: WETH_ADDRESS,
      symbol: "ETH",
      name: "Ethereum",
      decimals: 18,
      icon: "⚡",
      expectedAPY: "~4%"
    }
  };

  // Read contract data
  const { data: userTotalStaked } = useReadContract({
    address: STAKING_VAULT_ADDRESS,
    abi: [
      {
        name: "getUserTotalStaked",
        type: "function",
        stateMutability: "view",
        inputs: [{ type: "address" }],
        outputs: [{ type: "uint256" }]
      }
    ],
    functionName: "getUserTotalStaked",
    args: connectedAddress ? [connectedAddress] : undefined
  });

  const { data: userShares } = useReadContract({
    address: STAKING_VAULT_ADDRESS,
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
    args: connectedAddress ? [connectedAddress] : undefined
  });

  const { data: boostMultiplier } = useReadContract({
    address: STAKING_VAULT_ADDRESS,
    abi: [
      {
        name: "getBoostMultiplier",
        type: "function",
        stateMutability: "view",
        inputs: [{ type: "address" }],
        outputs: [{ type: "uint256" }]
      }
    ],
    functionName: "getBoostMultiplier",
    args: connectedAddress ? [connectedAddress] : undefined
  });

  const { data: userYieldRate } = useReadContract({
    address: STAKING_VAULT_ADDRESS,
    abi: [
      {
        name: "getUserYieldRate",
        type: "function",
        stateMutability: "view",
        inputs: [{ type: "address" }, { type: "address" }],
        outputs: [{ type: "uint256" }]
      }
    ],
    functionName: "getUserYieldRate",
    args: connectedAddress ? [connectedAddress, assets[selectedAsset].address] : undefined
  });

  const { data: totalValueLocked } = useReadContract({
    address: STAKING_VAULT_ADDRESS,
    abi: [
      {
        name: "getTotalValueLocked",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [{ type: "uint256" }]
      }
    ],
    functionName: "getTotalValueLocked"
  });

  // Write contract hooks
  const { 
    writeContract: deposit, 
    isPending: isDepositPending,
    data: depositHash 
  } = useWriteContract();

  const { 
    writeContract: withdraw, 
    isPending: isWithdrawPending,
    data: withdrawHash 
  } = useWriteContract();

  const { 
    writeContract: lockAGN, 
    isPending: isLockPending,
    data: lockHash 
  } = useWriteContract();

  // Calculate effective yield rate
  const getEffectiveYieldRate = () => {
    if (!userYieldRate) return assets[selectedAsset].expectedAPY;
    
    const baseRate = Number(userYieldRate) / 100; // Convert from basis points
    const hasBoost = boostMultiplier && Number(boostMultiplier) > 10000;
    
    return hasBoost ? `${baseRate.toFixed(1)}% (+5% boost)` : `${baseRate.toFixed(1)}%`;
  };

  const handleStake = async () => {
    if (!stakeAmount || !connectedAddress) return;
    
    try {
      const amount = selectedAsset === "USDC" 
        ? parseUnits(stakeAmount, 6) 
        : parseEther(stakeAmount);
      
      deposit({
        address: STAKING_VAULT_ADDRESS,
        abi: [
          {
            name: "deposit",
            type: "function",
            stateMutability: selectedAsset === "ETH" ? "payable" : "nonpayable",
            inputs: [
              { name: "asset", type: "address" },
              { name: "amount", type: "uint256" }
            ],
            outputs: [{ type: "uint256" }]
          }
        ],
        functionName: "deposit",
        args: [assets[selectedAsset].address, amount],
        value: selectedAsset === "ETH" ? amount : undefined
      });

      notification.success("Staking transaction submitted!");
    } catch (error) {
      console.error("Staking failed:", error);
      notification.error("Staking failed");
    }
  };

  const handleWithdraw = async () => {
    if (!withdrawShares || !connectedAddress) return;
    
    try {
      const shares = parseEther(withdrawShares);
      
      withdraw({
        address: STAKING_VAULT_ADDRESS,
        abi: [
          {
            name: "withdraw",
            type: "function",
            stateMutability: "nonpayable",
            inputs: [
              { name: "asset", type: "address" },
              { name: "shares", type: "uint256" }
            ],
            outputs: [{ type: "uint256" }]
          }
        ],
        functionName: "withdraw",
        args: [assets[selectedAsset].address, shares]
      });

      notification.success("Withdrawal transaction submitted!");
    } catch (error) {
      console.error("Withdrawal failed:", error);
      notification.error("Withdrawal failed");
    }
  };

  const handleLockAGN = async () => {
    if (!lockAmount || !connectedAddress) return;
    
    try {
      const amount = parseEther(lockAmount);
      const duration = lockDuration * 24 * 60 * 60; // Convert days to seconds
      
      lockAGN({
        address: STAKING_VAULT_ADDRESS,
        abi: [
          {
            name: "lockAGN",
            type: "function",
            stateMutability: "nonpayable",
            inputs: [
              { name: "amount", type: "uint256" },
              { name: "lockDuration", type: "uint256" }
            ],
            outputs: []
          }
        ],
        functionName: "lockAGN",
        args: [amount, duration]
      });

      notification.success("AGN lock transaction submitted!");
    } catch (error) {
      console.error("AGN lock failed:", error);
      notification.error("AGN lock failed");
    }
  };

  return (
    <div className="bg-base-100 border-base-300 border shadow-md shadow-secondary rounded-3xl px-6 py-8 w-full max-w-lg mx-auto">
      {/* Header */}
      <div className="flex flex-col items-center mb-6">
        <div className="text-4xl mb-2">🏪</div>
        <h2 className="text-2xl font-bold text-center">Staking Vault</h2>
        <p className="text-sm text-base-content/70 text-center">Earn Yields with AGN Boosts</p>
      </div>

      {/* Mode Toggle */}
      <div className="flex bg-base-200 rounded-2xl p-1 mb-6">
        <button
          className={`flex-1 py-2 px-4 rounded-xl font-medium transition-all ${
            isStaking 
              ? "bg-primary text-primary-content shadow-sm" 
              : "text-base-content/70 hover:text-base-content"
          }`}
          onClick={() => setIsStaking(true)}
        >
          Stake
        </button>
        <button
          className={`flex-1 py-2 px-4 rounded-xl font-medium transition-all ${
            !isStaking 
              ? "bg-primary text-primary-content shadow-sm" 
              : "text-base-content/70 hover:text-base-content"
          }`}
          onClick={() => setIsStaking(false)}
        >
          Withdraw
        </button>
      </div>

      {/* Asset Selector */}
      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">Asset</label>
        <div className="grid grid-cols-2 gap-2">
          {Object.entries(assets).map(([key, asset]) => (
            <button
              key={key}
              className={`p-3 rounded-xl border transition-all ${
                selectedAsset === key
                  ? "border-primary bg-primary/10 text-primary"
                  : "border-base-300 hover:border-base-content/30"
              }`}
              onClick={() => setSelectedAsset(key as keyof typeof assets)}
            >
              <div className="text-lg mb-1">{asset.icon}</div>
              <div className="text-xs font-medium">{asset.symbol}</div>
              <div className="text-xs text-base-content/50">{asset.expectedAPY}</div>
            </button>
          ))}
        </div>
      </div>

      {isStaking ? (
        <>
          {/* Stake Amount Input */}
          <div className="mb-4">
            <label className="block text-sm font-medium mb-2">Amount</label>
            <div className="relative">
              <input
                type="number"
                placeholder={selectedAsset === "USDC" ? "1000" : "1.0"}
                className="input input-bordered w-full pr-16"
                value={stakeAmount}
                onChange={(e) => setStakeAmount(e.target.value)}
              />
              <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-sm font-medium text-base-content/70">
                {assets[selectedAsset].symbol}
              </div>
            </div>
          </div>

          {/* Yield Preview */}
          {stakeAmount && Number(stakeAmount) > 0 && (
            <div className="bg-success/10 border border-success/20 rounded-2xl p-4 mb-6">
              <h3 className="font-medium mb-3 flex items-center text-success">
                <span className="text-lg mr-2">📈</span>
                Yield Preview
              </h3>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span>Base APY:</span>
                  <span className="font-medium">{assets[selectedAsset].expectedAPY}</span>
                </div>
                <div className="flex justify-between">
                  <span>Your Rate:</span>
                  <span className="font-medium text-success">{getEffectiveYieldRate()}</span>
                </div>
                <div className="flex justify-between">
                  <span>Protocol Fee:</span>
                  <span className="font-medium">5%</span>
                </div>
                <div className="border-t pt-2 mt-2">
                  <div className="flex justify-between text-xs text-base-content/70">
                    <span>Strategy: {selectedAsset === "USDC" ? "Aave" : "Lido"}</span>
                    <span>Auto-compound</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Stake Button */}
          <button
            className="btn btn-primary w-full"
            onClick={handleStake}
            disabled={!stakeAmount || !connectedAddress || isDepositPending}
          >
            {!connectedAddress 
              ? "Connect Wallet" 
              : isDepositPending
              ? "Staking..."
              : `Stake ${selectedAsset}`
            }
          </button>
        </>
      ) : (
        <>
          {/* User Position */}
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
                <span>Total Staked:</span>
                <span className="font-medium">
                  ${userTotalStaked ? formatUnits(userTotalStaked, 18) : "0.00"}
                </span>
              </div>
            </div>
          </div>

          {/* Withdraw Input */}
          <div className="mb-4">
            <label className="block text-sm font-medium mb-2">Shares to Withdraw</label>
            <div className="relative">
              <input
                type="number"
                placeholder="0.00"
                className="input input-bordered w-full pr-20"
                value={withdrawShares}
                onChange={(e) => setWithdrawShares(e.target.value)}
              />
              <button 
                className="absolute right-3 top-1/2 transform -translate-y-1/2 text-xs btn btn-ghost btn-xs"
                onClick={() => setWithdrawShares(userShares ? formatEther(userShares) : "0")}
              >
                MAX
              </button>
            </div>
          </div>

          {/* Withdraw Button */}
          <button
            className="btn btn-secondary w-full"
            onClick={handleWithdraw}
            disabled={!withdrawShares || !connectedAddress || isWithdrawPending}
          >
            {!connectedAddress 
              ? "Connect Wallet" 
              : isWithdrawPending
              ? "Withdrawing..."
              : `Withdraw to ${selectedAsset}`
            }
          </button>
        </>
      )}

      {/* AGN Boost Section */}
      <div className="border-t border-base-300 pt-6 mt-6">
        <h3 className="font-medium mb-4 flex items-center">
          <span className="text-lg mr-2">🚀</span>
          AGN Boost (+5% Yield)
        </h3>
        
        <div className="bg-warning/10 border border-warning/20 rounded-2xl p-4 mb-4">
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span>Current Boost:</span>
              <span className="font-medium text-warning">
                {boostMultiplier && Number(boostMultiplier) > 10000 ? "+5%" : "None"}
              </span>
            </div>
            <div className="flex justify-between">
              <span>Boost Status:</span>
              <span className="font-medium">
                {boostMultiplier && Number(boostMultiplier) > 10000 ? "Active" : "Lock AGN to activate"}
              </span>
            </div>
          </div>
        </div>

        {/* AGN Lock Interface */}
        <div className="grid grid-cols-2 gap-2 mb-4">
          <div>
            <label className="block text-xs font-medium mb-1">AGN Amount</label>
            <input
              type="number"
              placeholder="1000"
              className="input input-bordered input-sm w-full"
              value={lockAmount}
              onChange={(e) => setLockAmount(e.target.value)}
            />
          </div>
          <div>
            <label className="block text-xs font-medium mb-1">Lock Days</label>
            <select
              className="select select-bordered select-sm w-full"
              value={lockDuration}
              onChange={(e) => setLockDuration(Number(e.target.value))}
            >
              <option value={30}>30 days</option>
              <option value={90}>90 days</option>
              <option value={180}>180 days</option>
              <option value={365}>365 days</option>
            </select>
          </div>
        </div>

        <button
          className="btn btn-warning btn-sm w-full"
          onClick={handleLockAGN}
          disabled={!lockAmount || !connectedAddress || isLockPending}
        >
          {isLockPending ? "Locking..." : "Lock AGN for Boost"}
        </button>
      </div>

      {/* Footer Stats */}
      <div className="mt-6 pt-4 border-t border-base-300">
        <div className="grid grid-cols-2 gap-4 text-center text-sm">
          <div>
            <div className="text-base-content/50">Total TVL</div>
            <div className="font-medium">
              ${totalValueLocked ? Number(formatUnits(totalValueLocked, 18)).toLocaleString() : "0"}
            </div>
          </div>
          <div>
            <div className="text-base-content/50">Protocol Fee</div>
            <div className="font-medium">5%</div>
          </div>
        </div>
      </div>
    </div>
  );
};
