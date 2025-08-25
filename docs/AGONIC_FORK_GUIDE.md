# Agonic Fork Setup Guide

## What You're Doing

1. **StableSwap** (this repo) → **Open source DEX aggregator** (clean, focused)
2. **Agonic Fork** (new repo) → **Your main product** (vault + ETH treasury + app chain)

---

## Files to Bring to Agonic Fork

### **Planning Documents** ✅ 
1. `AGONIC_PHASE1_ROADMAP.md` — Day one product (4-8 weeks)
2. `AGONIC_PHASE2_APPCHAIN.md` — App chain evolution (6-12 months) 
3. `AGONIC_EXTENDED_ROADMAP.md` — Full technical specification
4. `ROADMAP.md` — Original Taska context (for reference)

### **StableSwap Foundation** ✅
**Core code to adapt:**
```
apps/stable-swap/src/
├── lib/
│   ├── config.ts           # Env management → adapt for multi-stablecoin vault
│   ├── math.ts             # BPS calculations → reuse for fees/CR/FX
│   ├── viem.ts             # Base L2 client → reuse for DCA/rebalancing
│   ├── tokens.ts           # Token metadata → expand for USDC/USD1/EURC/AGN
│   └── venues/             # Multi-protocol integrations → strategy adapters
│       ├── univ3.ts        # → Uniswap V3 LP strategy + concentrated liquidity
│       ├── aerodrome.ts    # → Aerodrome stable LP + reward harvesting
│       ├── aave.ts         # → NEW: Aave v3 lending integration
│       └── wlf.ts          # → NEW: World Liberty Financial adapter
├── components/
│   └── SwapCard.tsx        # → VaultCard.tsx (multi-asset deposit/withdraw)
└── app/api/
    ├── quote/route.ts      # → vault/apy endpoint (multi-protocol)
    ├── fx/implied/route.ts # → FX arbitrage opportunities (EURC/USDC/USD1)
    └── rebalance/route.ts  # → NEW: Dynamic strategy allocation
```

**Smart contract foundation:**
```
contracts/src/
└── RouterExecutor.sol      # Fee collection pattern → Treasury.sol
```

---

## Agonic Fork Repository Structure

```
agonic/
├── README.md                           # Agonic project overview
├── AGONIC_PHASE1_ROADMAP.md            # Main implementation plan
├── AGONIC_PHASE2_APPCHAIN.md           # App chain evolution  
├── AGONIC_EXTENDED_ROADMAP.md          # Technical specification
├── apps/
│   ├── web/                            # Vault dashboard (adapted from stable-swap)
│   │   ├── src/
│   │   │   ├── components/
│   │   │   │   ├── VaultCard.tsx       # Deposit/withdraw (from SwapCard)
│   │   │   │   ├── TreasuryChart.tsx   # ETH accumulation display
│   │   │   │   └── NotesPanel.tsx      # ATN subscription interface
│   │   │   ├── lib/                    # Reuse StableSwap lib/
│   │   │   └── app/api/
│   │   │       ├── vault/
│   │   │       ├── treasury/
│   │   │       └── bonds/
│   │   └── package.json                # Add vault-specific deps
│   └── ops/                            # Operational scripts
│       ├── harvest.ts                  # Weekly yield collection
│       ├── dca.ts                      # Weekly ETH purchases  
│       └── coupons.ts                  # ATN coupon payments
├── packages/
│   ├── protocol/                       # Smart contracts
│   │   ├── StableVault4626.sol         # Multi-asset vault (USDC/USD1/EURC)
│   │   ├── TreasuryManager.sol         # Multi-protocol integration controller
│   │   ├── strategies/                 # Protocol-specific adapters
│   │   │   ├── AaveAdapter.sol         # Aave v3 lending strategy
│   │   │   ├── WLFAdapter.sol          # World Liberty Financial integration
│   │   │   ├── UniswapAdapter.sol      # Uniswap V3 concentrated liquidity
│   │   │   └── AerodromeAdapter.sol    # Aerodrome stable LP management
│   │   ├── Treasury.sol                # ETH DCA + FX arbitrage logic
│   │   ├── BondManager.sol             # ATN issuance with multi-asset support
│   │   ├── ATNTranche.sol              # Note implementation (new)
│   │   ├── Buyback.sol                 # AGN buybacks with LP governance
│   │   ├── Gov.sol                     # LP staker + AGN holder governance
│   │   └── AttestationEmitter.sol      # Strategy performance transparency
│   └── sdk/                            # TypeScript SDK
│       ├── vault.ts                    # Vault interaction utilities
│       ├── treasury.ts                 # Treasury state queries
│       └── bonds.ts                    # ATN subscription helpers
├── governance/                         # Future community proposals
│   └── future-proposals/               # Directory for community AIPs
└── phase2-appchain/                    # Future app chain (Phase 2)
    ├── agonic-chain/                   # Cosmos SDK modules
    ├── bridge-contracts/               # Base L2 ↔ Agonic bridge
    └── validator-tools/                # Validator setup guides
```

---

## Next Steps

### **1. Create Agonic Fork**
```bash
# Fork StableSwap to new Agonic repo
git clone https://github.com/your-username/StableSwap.git agonic
cd agonic
git remote set-url origin https://github.com/your-username/agonic.git
```

### **2. Copy Planning Files**
```bash
# These files are ready in your StableSwap directory
cp AGONIC_*.md ../agonic/
cp ROADMAP.md ../agonic/
```

### **3. Restructure for Agonic**
```bash
cd agonic
mkdir -p packages/protocol packages/sdk governance phase2-appchain
mv apps/stable-swap apps/web
# Adapt apps/web for vault interface
# Create new smart contracts in packages/protocol
```

### **4. First Implementation Target**
**Foundation Goal:** Multi-protocol vault + treasury working on Base L2
1. Deploy `StableVault4626.sol` (Multi-asset vault: USDC, USD1, EURC)
2. Deploy `AaveAdapter.sol` (Base yield floor via Aave v3 integration)
3. Deploy `TreasuryManager.sol` (Multi-protocol rebalancing controller)
4. Deploy `Treasury.sol` (ETH DCA + FX arbitrage capabilities)  
5. Build vault UI (Multi-asset deposit/withdraw with yield comparison)

---

## Key Technical Adaptations

### **RouterExecutor.sol → Treasury.sol**
Your fee collection pattern (lines 70-75) is perfect foundation:
```solidity
// Current: fee = (outBal * feeBps) / 10_000;
// Agonic: treasuryShare = (yieldAmount * YIELD_FEE_BPS) / 10_000;
```

### **SwapCard.tsx → VaultCard.tsx**  
Your React patterns work perfectly for vault:
```typescript
// Current: amountIn, tokenIn, tokenOut → getRoute()
// Agonic: depositAmount, USDC only → deposit() / withdraw()
```

### **Venue Logic → Multi-Protocol Strategy Logic**
Your multi-venue comparison becomes automated yield optimization:
```typescript
// Current: Compare Uniswap vs Aerodrome for best price
// Agonic: Compare Aave, WLF, Uniswap LP, Aerodrome for best risk-adjusted yield
// Auto-rebalance based on performance + enforce protocol allocation caps
// Execute FX arbitrage opportunities across EURC/USDC/USD1 pairs
```

---

**You're 60-70% of the way there with existing StableSwap code!**
