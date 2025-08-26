# Agonic — Ultra-Simple Treasury Protocol (Extended Plan)

**Tagline:** *Stake assets → earn yield with AGN boosts → protocol accumulates pure ETH → disciplined $AGN buybacks with 80% burns.*  
**Focus:** Ultra-minimal mechanics: USDC bonds fund ETH treasury, core staking vault with AGN boosts, automatic buybacks burn 80% for maximum deflation. Set it and forget it.

---

## 0) Executive Summary

Agonic is an **ultra-simple treasury protocol** that accumulates pure ETH through USDC bonds and staking fees, then performs **aggressive AGN buybacks with 80% burns**. No complex POL, no multi-asset bonds, no dynamic rebalancing—just pure ETH accumulation and maximum token deflation.

**Three core mechanisms (and only three):**
1. **USDC Bonds** — 10% discount, 7-day vest, 100% proceeds to ETH treasury
2. **Core Staking Vault** — USDC/ETH staking with 5% fee, AGN boosts for lockers
3. **Automatic Buybacks** — 80% burn / 20% treasury split on all inflows

---

## 1) Ultra-Simple User Experience

### 1.1 Simple USDC Bonds
- **Deposit**: USDC → receive 10% discounted AGN (7-day vest)
- **Proceeds**: 100% to pure ETH treasury buys/holds (Lido staking)
- **No Complexity**: Single bond type, fixed discount, automatic execution

### 1.2 Core Staking Vault
- **Assets**: Stake USDC/ETH for competitive yields (5% fee to treasury)
- **USDC Yields**: Fixed Aave lending (8-12% APR) — single lender, no rebalancing
- **ETH Yields**: Direct Lido staking (~4% APR) for liquid staking rewards
- **AGN Boosts**: Lockers get +5% yield boost (funded from 20% of fees)

### 1.3 Pure ETH Treasury
- **Focus**: 100% pure ETH hold/stake — no POL/IL exposure
- **Growth**: All inflows (bonds + staking fees) accumulate as ETH
- **Backing**: Treasury Per Token (TPT) metric grows mechanically

### 1.4 Automatic Buybacks
- **Trigger**: Automatic on all inflows (bonds + staking fees)
- **Split**: 80% burn AGN immediately, 20% to treasury for operations
- **Execution**: 3-day TWAP for safe, simple execution

---

## 2) Pure ETH Treasury Strategy

### 2.1 ETH Inflows
1. **Bond Proceeds**: 100% of USDC bonds → ETH treasury buys
2. **Staking Fees**: 80% of vault fees → ETH buybacks → burns
3. **ETH Staking**: Treasury ETH staked via Lido for compound growth

### 2.2 Safety Gates (Built-in Discipline)
1. **Runway Buffer**: Maintain ≥6 months OPEX before buybacks
2. **Coverage Ratio**: CR ≥1.2× for all operations
3. **Burn Throttle**: If runway/CR low, burn 50% (else 80%)
4. **Pool Depth**: Min $50K liquidity before buybacks execute

### 2.3 AGN Value Drivers (Mechanical)
1. **Aggressive Deflation**: 80% burns reduce supply continuously
2. **ETH Backing**: Pure ETH treasury grows TPT metric
3. **Utility**: Governance votes + staking boosts drive demand
4. **Fixed Supply**: No emissions, only burns

---

## 3) Simplified Parameters

| Parameter | Value |
|---|---|
| Bond Assets | USDC only |
| Bond Discount | 10% fixed |
| Bond Vesting | 7 days linear |
| Staking Assets | USDC, ETH |
| USDC Strategy | Fixed Aave lending (8-12% APR) |
| ETH Strategy | Lido staking (~4% APR) |
| Vault Fee | 5% of yields |
| AGN Boost | +5% for lockers |
| Buyback Split | 80% burn / 20% treasury |
| TWAP Period | 3 days |
| Safety Gates | Runway ≥6m, CR ≥1.2×, Pool ≥$50K |

---

## 4) Ultra-Simple Architecture

**Core Contracts (Minimal):**
1. **SimpleBond.sol** — USDC-only bonds, fixed 10% discount, 7-day vest
2. **StakingVault.sol** — ERC-4626 for USDC/ETH with AGN boosts
3. **Treasury.sol** — ETH accumulation, auto-buyback pipe, Chainlink pricing
4. **Buyback.sol** — 80% burn / 20% treasury split, TWAP execution
5. **Gov.sol** — AGN holder governance
6. **AttestationEmitter.sol** — Transparency events

**Simple Adapters:**
- **AaveAdapter.sol** — Fixed USDC lending (no rebalancing)
- **LidoAdapter.sol** — ETH staking integration

**No Complex Systems:**
- ❌ TreasuryManager.sol (no dynamic rebalancing)
- ❌ BondManager.sol + ATNTranche.sol (replaced by SimpleBond)
- ❌ POLManager.sol (no POL strategy)
- ❌ LPStaking.sol (no LP rewards)

---

## 5) Implementation Timeline (2 Days)

**Day 1: Contracts & Tests**
- Complete SimpleBond.sol, StakingVault.sol
- Update Treasury.sol with auto-buyback pipe
- Update Buyback.sol with 80/20 split
- Write comprehensive unit and integration tests

**Day 2: Frontend & Deployment**
- Build basic frontend for bond/staking
- Deploy contracts with safety parameters
- Full integration testing and mainnet deployment

---

## 6) Success Metrics

**Week 1:**
- Bond fill rate >50%
- Staking TVL >$100K
- Buybacks executing automatically
- TPT published weekly

**Month 1:**
- Total TVL >$1M
- Consistent 80% burn rate
- ETH treasury growing
- AGN supply decreasing

**6 Months:**
- Path to $1B TVL via institutional staking
- Significant AGN supply reduction
- Strong ETH treasury backing
- Proven automated execution

---

## 7) Risk Management

**Built-in Protections:**
- Fixed parameters (no dynamic complexity)
- Safety gates enforce runway/CR minimums
- Burn throttle prevents treasury depletion
- Chainlink pricing prevents oracle manipulation
- Single-venue strategies reduce protocol risk

**Emergency Controls:**
- Pause bond issuance
- Pause buyback execution
- Emergency treasury withdrawal
- Governance parameter updates

---

**Agonic v1: Ultra-simple, pure ETH treasury, aggressive AGN burns. Set it and forget it.**