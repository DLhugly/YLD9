# Agonic — Full Roadmap (v1)

**Tagline:** *Deposit stables → earn conservative yield → protocol accumulates ETH (MicroStrategy-style) → disciplined $AGN buybacks governed by safety gates.*  
**Scope:** One killer product. Taska ideas are folded in as **transparency + fee-positive mini-apps**, without altering the core. AgentPayy is deferred.

---

## 0) Executive Summary

Agonic is a **stable-yield vault with a treasury that DCA-buys ETH** and, once safety gates are green, performs **programmatic $AGN buybacks**.  
We add a **bond program (ATN)** to scale the ETH balance sheet prudently. Taska's "Proof-of-Task" becomes a **lightweight Agent Activity Oracle**—for **transparency**, not settlement.

**Three levers (and only three at launch):**
1. **Fee on Yield (vault)** — never on principal.  
2. **Weekly DCA cap (treasury)** — ETH accumulation, runway-aware.  
3. **Buyback policy (40% of Net Yield)** — gated by **Runway** and **Coverage Ratio**.

---

## 1) Day-One Product (What ships)

### 1.1 User Experience
1. **Multi-Stablecoin Vault (ERC-4626)**: deposit/withdraw USDC, USD1, EURC; **dynamic allocation** across proven Base protocols (Aave, WLF, Uniswap V3, Aerodrome); **allocation caps enforced** per protocol.
2. **ETH Reserve + FX Transparency**: Treasury performs **weekly DCA** with optimal routing plus **FX arbitrage** across stablecoin pairs; every trade and rebalancing action logged on-chain.
3. **Optional ETH Boost**: users may elect to receive **a % of their yield in ETH** (principal remains in chosen stablecoin).
4. **Enhanced ATN Program**: on-chain fixed-APR **multi-stablecoin notes** (non-transferable until maturity) to accelerate ETH accumulation and FX strategy funding.

### 1.2 Token Flywheel (TIP-11 merged)
1. **40% of Net Yield (NY)** → **Buyback Pool** (BP), when safety gates are green.
2. **Buyback Split:** **50% burn / 50% to treasury** (treasury-held AGN = long-term alignment).
3. **LP staking later**: single-sided staking is **retired**; **LP staking** (AGN/ETH, AGN/USDC) can be enabled by AIP after launch with strict emission caps.
4. **POL & bonding later**: grow protocol-owned liquidity after KPIs are stable.

---

## 2) MicroStrategy-Style ETH Reserve (Why & How)

### 2.1 Two ETH inflows
1) **Fee on yield** from the vault (**12%** of realized yield, never on principal) → Treasury.  
2) **ATN bond proceeds** → **100%** routed to ETH DCA automatically.

### 2.2 Safety gates (discipline)
1. **Runway buffer:** maintain **≥ 6 months OPEX (USDC)** before any DCA or buybacks.  
2. **Coverage Ratio (CR):**  
  $$ CR = \frac{Treasury\ USDC + Treasury\ ETH \times ETHUSD}{ATN\ Principal\ Outstanding} $$  
  Require **CR ≥ 1.2×**; if breached, **auto-pause** new ATN issuance & buybacks (DCA may proceed under reduced caps).

### 2.3 $AGN value drivers (mechanical, not promises)
1. Programmatic buybacks (40% of NY; gates on) via **TWAP/split orders** → **50% burn / 50% treasury**.  
2. **Governance utility** over three scarce knobs; potential **priority ATN access**; **LP staking rewards/bonding discounts** later.  
3. **TPT (Treasury-per-Token)** published weekly (informational transparency metric).  
4. **Fixed supply** (e.g., 200M AGN). No emissions v1; incentives (if any) come from treasury-held AGN via AIP.

---

## 3) Parameters (initial, changeable via AIP)

| Parameter | Initial |
|---|---|
| Vault assets | USDC, USD1, EURC (Base L2) |
| Base strategy | Aave v3 lending (guaranteed yield floor) |
| Protocol allocation | Aave ≤ **60% TVL**, WLF ≤ **40% TVL**, LP strategies ≤ **30% TVL** each |
| Idle buffer | **≥ 20% TVL** (across all stablecoins) |
| Fee on Yield | **12%** (never on principal) |
| Runway buffer | **6 months** OPEX (multi-stablecoin) |
| Weekly DCA cap | **$5,000** equivalent (scales with TVL) |
| FX arbitrage | Enabled for EURC/USDC/USD1 pairs |
| FX arbitrage threshold | **0.1%** minimum deviation for automatic execution |
| ETH staking allocation | **≤20%** of treasury ETH via Lido/Rocket Pool |
| Buyback pool | **40% of NY** (gated, includes FX profits + staking rewards) |
| Buyback split | **50% burn / 50% treasury** |
| LP governance | LP stakers vote on high-risk strategies |
| CR minimum | **1.2×** (multi-asset treasury) |
| ATN-01 tranche | **$250k** cap; **8% APR**; **6m** term; multi-stablecoin; non-transferable |

---

## 4) Architecture Overview (How)

**Smart Contract Suite:**
1. **StableVault4626.sol** — Multi-asset ERC-4626 vault (USDC/USD1/EURC) with yield fee collection
2. **TreasuryManager.sol** — Multi-protocol rebalancing controller with dynamic allocation
3. **Protocol Adapters:**
   - **AaveAdapter.sol** — Aave v3 lending integration for yield floor
   - **WLFAdapter.sol** — World Liberty Financial vault integration
   - **UniswapAdapter.sol** — Uniswap V3 concentrated liquidity management  
   - **AerodromeAdapter.sol** — Aerodrome stable LP strategies
4. **Treasury.sol** — Multi-stablecoin/ETH holdings, DCA execution, **automated FX arbitrage thresholds**, **ETH staking integration**, runway/CR tracking
5. **BondManager.sol + ATNTranche.sol** — Fixed-APR multi-stablecoin note issuance and management
6. **Buyback.sol** — TWAP AGN purchases with LP governance integration, burn/treasury split
7. **Gov.sol** — Dual governance (AGN holders + LP stakers) over protocol integrations and parameters
8. **AttestationEmitter.sol** — Strategy performance and rebalancing transparency events

**Integration Points:**
1. **Vault ↔ StrategyAdapter** — Yield generation and harvest
2. **Vault ↔ Treasury** — Fee routing and ETH conversion option
3. **Treasury ↔ BondManager** — ATN proceeds to DCA
4. **Treasury ↔ Buyback** — Net yield allocation when gates pass
5. **All ↔ AttestationEmitter** — Event logging for transparency

**Security & Risk Management:**
1. **Venue caps** — Maximum 60% TVL exposure to any single protocol
2. **Idle buffer** — Minimum 20% TVL kept liquid for withdrawals  
3. **Safety gates** — Runway and CR requirements before risk activities
4. **Emergency controls** — Independent pause mechanisms for each module
5. **Governance timelock** — Parameter changes subject to delay

---

## 5) Roadmap to Production

**Week 1-2: Core Infrastructure**
1. Deploy vault, strategy, treasury contracts on Base testnet
2. Build basic web interface for deposits/withdrawals  
3. Implement DCA and transparency logging

**Week 3-4: Bond Program**  
1. Deploy bond manager and ATN tranche contracts
2. Add notes subscription interface
3. Implement coverage ratio monitoring and gates

**Week 5-6: Buyback System**
1. Deploy buyback contract with TWAP mechanisms
2. Add AGN token and initial liquidity
3. Test full flywheel with safety gates

**Week 7-8: Production Launch**
1. Security audit and testing
2. Mainnet deployment with conservative caps
3. Community launch and initial user onboarding

---

**Agonic v1: Disciplined yield, ETH reserves, and mechanical token value accrual.**
