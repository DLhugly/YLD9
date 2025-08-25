# Agonic Fork Setup Guide

## What You're Doing

1. **StableSwap** (this repo) → **Open source DEX aggregator** (clean, focused)
2. **Agonic Fork** (new repo) → **Your main product** (vault + ETH treasury + app chain)

---

## Files to Bring to Agonic Fork

### **Planning Documents** ✅ 
- `AGONIC_PHASE1_ROADMAP.md` — Day one product (4-8 weeks)
- `AGONIC_PHASE2_APPCHAIN.md` — App chain evolution (6-12 months) 
- `AGONIC_EXTENDED_ROADMAP.md` — Full technical specification
- `ROADMAP.md` — Original Taska context (for reference)

### **StableSwap Foundation** ✅
**Core code to adapt:**
```
apps/stable-swap/src/
├── lib/
│   ├── config.ts           # Env management → adapt for vault
│   ├── math.ts             # BPS calculations → reuse for fees/CR
│   ├── viem.ts             # Base L2 client → reuse for DCA
│   ├── tokens.ts           # Token metadata → expand for AGN
│   └── venues/             # DEX integrations → adapt for strategies
│       ├── univ3.ts        # → StrategyAdapter pattern
│       └── aerodrome.ts    # → StrategyAdapter pattern
├── components/
│   └── SwapCard.tsx        # → VaultCard.tsx (deposit/withdraw)
└── app/api/
    ├── quote/route.ts      # → vault/apy endpoint
    └── fx/implied/route.ts # → treasury/dca endpoint
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
│   │   ├── StableVault4626.sol         # Main vault (new)
│   │   ├── StrategyAdapter.sol         # Venue integration (adapt venues/)
│   │   ├── Treasury.sol                # DCA + CR logic (adapt RouterExecutor)
│   │   ├── BondManager.sol             # ATN issuance (new)
│   │   ├── ATNTranche.sol              # Note implementation (new)
│   │   ├── Buyback.sol                 # AGN buybacks (new)
│   │   ├── Gov.sol                     # Parameter governance (new)
│   │   └── AttestationEmitter.sol      # Transparency events (new)
│   └── sdk/                            # TypeScript SDK
│       ├── vault.ts                    # Vault interaction utilities
│       ├── treasury.ts                 # Treasury state queries
│       └── bonds.ts                    # ATN subscription helpers
├── governance/                         # AIP proposals
│   ├── AIP-01_ETH_Reserve_Flywheel.md
│   └── AIP-02_Treasury_Notes.md
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
**Week 1-2 Goal:** Basic vault + treasury working on Base L2
- Deploy `StableVault4626.sol` (ERC-4626 USDC vault)
- Deploy `Treasury.sol` (adapted from RouterExecutor fee logic)
- Deploy `StrategyAdapter.sol` (reuse your venue expertise)  
- Build vault UI (adapt SwapCard → VaultCard)

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

### **Venue Logic → Strategy Logic**
Your multi-venue comparison becomes strategy optimization:
```typescript
// Current: Compare Uniswap vs Aerodrome for best price
// Agonic: Compare venues for best yield, enforce caps
```

---

**You're 60-70% of the way there with existing StableSwap code!**
