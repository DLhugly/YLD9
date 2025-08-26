"use client";

import { useState, useEffect } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { formatUnits, parseUnits } from "viem";
import { useTargetNetwork } from "~~/hooks/scaffold-eth";
import { notification } from "~~/utils/scaffold-eth";

/**
 * SimpleBondCard component - Ultra-simple USDC bonds with 10% discount
 * Based on SimpleBond.sol contract
 */
export const SimpleBondCard = () => {
  const { address: connectedAddress } = useAccount();
  const { targetNetwork } = useTargetNetwork();

  // State management
  const [usdcAmount, setUsdcAmount] = useState("");
  const [selectedBondId, setSelectedBondId] = useState<number | null>(null);

  // Contract addresses (would be from deployedContracts.ts)
  const SIMPLE_BOND_ADDRESS = "0x0000000000000000000000000000000000000000"; // Placeholder
  const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"; // Base USDC

  // Read contract data
  const { data: weeklyCapRemaining } = useReadContract({
    address: SIMPLE_BOND_ADDRESS,
    abi: [
      {
        name: "getWeeklyCapRemaining",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [{ type: "uint256" }]
      }
    ],
    functionName: "getWeeklyCapRemaining"
  });

  const { data: userBondCount } = useReadContract({
    address: SIMPLE_BOND_ADDRESS,
    abi: [
      {
        name: "getUserBondCount",
        type: "function",
        stateMutability: "view",
        inputs: [{ type: "address" }],
        outputs: [{ type: "uint256" }]
      }
    ],
    functionName: "getUserBondCount",
    args: connectedAddress ? [connectedAddress] : undefined
  });

  const { data: totalClaimable } = useReadContract({
    address: SIMPLE_BOND_ADDRESS,
    abi: [
      {
        name: "getTotalClaimable",
        type: "function",
        stateMutability: "view",
        inputs: [{ type: "address" }],
        outputs: [{ type: "uint256" }]
      }
    ],
    functionName: "getTotalClaimable",
    args: connectedAddress ? [connectedAddress] : undefined
  });

  const { data: agnPreview } = useReadContract({
    address: SIMPLE_BOND_ADDRESS,
    abi: [
      {
        name: "previewDeposit",
        type: "function",
        stateMutability: "view",
        inputs: [{ type: "uint256" }],
        outputs: [{ type: "uint256" }]
      }
    ],
    functionName: "previewDeposit",
    args: usdcAmount ? [parseUnits(usdcAmount, 6)] : undefined
  });

  // Write contract hooks
  const { 
    writeContract: deposit, 
    isPending: isDepositPending,
    data: depositHash 
  } = useWriteContract();

  const { 
    writeContract: claim, 
    isPending: isClaimPending,
    data: claimHash 
  } = useWriteContract();

  // Wait for transaction receipts
  const { isLoading: isDepositLoading } = useWaitForTransactionReceipt({
    hash: depositHash,
  });

  const { isLoading: isClaimLoading } = useWaitForTransactionReceipt({
    hash: claimHash,
  });

  // Calculate bond preview
  const calculateBondPreview = () => {
    if (!usdcAmount || isNaN(Number(usdcAmount))) return { agnAmount: 0, discount: 0 };
    
    const amount = Number(usdcAmount);
    const agnAmount = agnPreview ? Number(formatUnits(agnPreview, 18)) : amount * 1.1; // 10% discount
    const discount = (amount * 0.1); // 10% discount value
    
    return {
      agnAmount: agnAmount,
      discount: discount
    };
  };

  const bondPreview = calculateBondPreview();

  const handleDeposit = async () => {
    if (!usdcAmount || !connectedAddress) return;
    
    try {
      const usdcAmountParsed = parseUnits(usdcAmount, 6); // USDC has 6 decimals
      
      deposit({
        address: SIMPLE_BOND_ADDRESS,
        abi: [
          {
            name: "deposit",
            type: "function",
            stateMutability: "nonpayable",
            inputs: [{ name: "usdcAmount", type: "uint256" }],
            outputs: [{ type: "uint256" }]
          }
        ],
        functionName: "deposit",
        args: [usdcAmountParsed]
      });

      notification.success("Bond purchase transaction submitted!");
    } catch (error) {
      console.error("Bond purchase failed:", error);
      notification.error("Bond purchase failed");
    }
  };

  const handleClaimAll = async () => {
    if (!connectedAddress || !userBondCount || Number(userBondCount) === 0) return;
    
    try {
      // Create array of all bond IDs
      const bondIds = Array.from({ length: Number(userBondCount) }, (_, i) => i);
      
      claim({
        address: SIMPLE_BOND_ADDRESS,
        abi: [
          {
            name: "claimMultiple",
            type: "function",
            stateMutability: "nonpayable",
            inputs: [{ name: "bondIds", type: "uint256[]" }],
            outputs: [{ type: "uint256" }]
          }
        ],
        functionName: "claimMultiple",
        args: [bondIds]
      });

      notification.success("Claim transaction submitted!");
    } catch (error) {
      console.error("Claim failed:", error);
      notification.error("Claim failed");
    }
  };

  return (
    <div className="bg-base-100 border-base-300 border shadow-md shadow-secondary rounded-3xl px-6 py-8 w-full max-w-lg mx-auto">
      {/* Header */}
      <div className="flex flex-col items-center mb-6">
        <div className="text-4xl mb-2">🎫</div>
        <h2 className="text-2xl font-bold text-center">USDC Bonds</h2>
        <p className="text-sm text-base-content/70 text-center">10% Discount • 7-Day Vesting</p>
      </div>

      {/* Weekly Cap Status */}
      <div className="bg-base-200 rounded-2xl p-4 mb-6">
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm font-medium">Weekly Capacity</span>
          <span className="text-sm text-success">Available</span>
        </div>
        <div className="flex justify-between text-sm text-base-content/70">
          <span>Remaining:</span>
          <span>{weeklyCapRemaining ? formatUnits(weeklyCapRemaining, 18) : "100,000"} AGN</span>
        </div>
      </div>

      {/* USDC Input */}
      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">USDC Amount</label>
        <div className="relative">
          <input
            type="number"
            placeholder="1000"
            className="input input-bordered w-full pr-16"
            value={usdcAmount}
            onChange={(e) => setUsdcAmount(e.target.value)}
          />
          <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-sm font-medium text-base-content/70">
            USDC
          </div>
        </div>
      </div>

      {/* Bond Preview */}
      {usdcAmount && Number(usdcAmount) > 0 && (
        <div className="bg-primary/10 border border-primary/20 rounded-2xl p-4 mb-6">
          <h3 className="font-medium mb-3 flex items-center text-primary">
            <span className="text-lg mr-2">💰</span>
            Bond Preview
          </h3>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span>You Pay:</span>
              <span className="font-medium">{usdcAmount} USDC</span>
            </div>
            <div className="flex justify-between">
              <span>You Receive:</span>
              <span className="font-medium text-primary">{bondPreview.agnAmount.toFixed(2)} AGN</span>
            </div>
            <div className="flex justify-between text-success">
              <span>Discount Value:</span>
              <span className="font-medium">${bondPreview.discount.toFixed(2)}</span>
            </div>
            <div className="border-t pt-2 mt-2">
              <div className="flex justify-between text-xs text-base-content/70">
                <span>Vesting: 7 days linear</span>
                <span>10% discount</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Purchase Button */}
      <button
        className="btn btn-primary w-full mb-4"
        onClick={handleDeposit}
        disabled={!usdcAmount || !connectedAddress || isDepositPending || isDepositLoading}
      >
        {!connectedAddress 
          ? "Connect Wallet" 
          : isDepositPending || isDepositLoading
          ? "Purchasing..."
          : "Purchase Bond"
        }
      </button>

      {/* User Bonds Section */}
      {connectedAddress && (
        <div className="border-t border-base-300 pt-6">
          <h3 className="font-medium mb-4 flex items-center">
            <span className="text-lg mr-2">📋</span>
            Your Bonds
          </h3>
          
          <div className="bg-base-200 rounded-2xl p-4 mb-4">
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span>Active Bonds:</span>
                <span className="font-medium">{userBondCount ? Number(userBondCount) : 0}</span>
              </div>
              <div className="flex justify-between">
                <span>Claimable AGN:</span>
                <span className="font-medium text-success">
                  {totalClaimable ? formatUnits(totalClaimable, 18) : "0.00"}
                </span>
              </div>
            </div>
          </div>

          {/* Claim Button */}
          <button
            className="btn btn-success w-full"
            onClick={handleClaimAll}
            disabled={!totalClaimable || Number(totalClaimable) === 0 || isClaimPending || isClaimLoading}
          >
            {isClaimPending || isClaimLoading
              ? "Claiming..."
              : "Claim All Vested AGN"
            }
          </button>
        </div>
      )}

      {/* Safety Gates Status */}
      <div className="mt-6 pt-4 border-t border-base-300">
        <div className="grid grid-cols-2 gap-4 text-center text-sm">
          <div>
            <div className="text-base-content/50">Runway</div>
            <div className="font-medium text-success">6+ months</div>
          </div>
          <div>
            <div className="text-base-content/50">Coverage Ratio</div>
            <div className="font-medium text-success">1.2x+</div>
          </div>
        </div>
      </div>
    </div>
  );
};
