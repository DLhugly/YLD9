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
- **sUSD Vault (ERC-4626, USDC only)**: deposit/withdraw; **one safe venue** on Base; **no leverage**; venue caps enforced.
- **ETH Reserve Transparency**: Treasury performs **weekly DCA** USDC→ETH; every trade logs on-chain and to the dashboard.
- **Optional ETH Boost**: users may elect to receive **a % of their yield in ETH** (principal remains in USDC).
- **Agonic Treasury Notes (ATN)**: on-chain fixed-APR **USDC notes** (non-transferable until maturity) to accelerate ETH accumulation.

### 1.2 Token Flywheel (TIP-11 merged)
- **40% of Net Yield (NY)** → **Buyback Pool** (BP), when safety gates are green.
- **Buyback Split:** **50% burn / 50% to treasury** (treasury-held AGN = long-term alignment).
- **LP staking later**: single-sided staking is **retired**; **LP staking** (AGN/ETH, AGN/USDC) can be enabled by AIP after launch with strict emission caps.
- **POL & bonding later**: grow protocol-owned liquidity after KPIs are stable.

---

## 2) MicroStrategy-Style ETH Reserve (Why & How)

### 2.1 Two ETH inflows
1) **Fee on yield** from the vault (e.g., 10–15% of realized yield, net of gas) → Treasury.  
2) **ATN bond proceeds** → **100%** routed to ETH DCA per AIP-02.

### 2.2 Safety gates (discipline)
- **Runway buffer:** maintain **≥ 6 months OPEX (USDC)** before any DCA or buybacks.  
- **Coverage Ratio (CR):**  
  $$ CR = \frac{Treasury\ USDC + Treasury\ ETH \times ETHUSD}{ATN\ Principal\ Outstanding} $$  
  Require **CR ≥ 1.2×**; if breached, **auto-pause** new ATN issuance & buybacks (DCA may proceed under reduced caps).

### 2.3 $AGN value drivers (mechanical, not promises)
- Programmatic buybacks (40% of NY; gates on) via **TWAP/split orders** → **50% burn / 50% treasury**.  
- **Governance utility** over three scarce knobs; potential **priority ATN access**; **LP boosts/bonding discounts** later.  
- **TPT (Treasury-per-Token)** published weekly (informational transparency metric).  
- **Fixed supply** (e.g., 200M AGN). No emissions v1; incentives (if any) come from treasury-held AGN via AIP.

---

## 3) Parameters (initial, changeable via AIP)

| Parameter | Initial |
|---|---|
| Vault asset | USDC (Base) |
| Strategy | One blue-chip venue, **cap ≤ 60% TVL**, no leverage |
| Idle buffer | **≥ 20% TVL** |
| Fee on Yield | **12%** (never on principal) |
| Runway buffer | **6 months** OPEX |
| Weekly DCA cap | **$5,000** USDC (scales with TVL) |
| Buyback pool | **40% of NY** (gated) |
| Buyback split | **50% burn / 50% treasury** |
| CR minimum | **1.2×** |
| ATN-01 tranche | **$250k** cap; **8% APR**; **6m** term; non-transferable until maturity |

---

## 4) Architecture Overview (How)

**Smart Contract Suite:**
- **StableVault4626.sol** — ERC-4626 USDC vault with yield fee collection
- **StrategyAdapter.sol** — Single venue adapter with safety caps  
- **Treasury.sol** — USDC/ETH holdings, DCA execution, runway/CR tracking
- **BondManager.sol + ATNTranche.sol** — Fixed-APR note issuance and management
- **Buyback.sol** — TWAP AGN purchases with burn/treasury split
- **Gov.sol** — Governance over key parameters  
- **AttestationEmitter.sol** — Transparency events for dashboard

**Integration Points:**
- **Vault ↔ StrategyAdapter** — Yield generation and harvest
- **Vault ↔ Treasury** — Fee routing and ETH conversion option
- **Treasury ↔ BondManager** — ATN proceeds to DCA
- **Treasury ↔ Buyback** — Net yield allocation when gates pass
- **All ↔ AttestationEmitter** — Event logging for transparency

**Security & Risk Management:**
- **Venue caps** — Maximum 60% TVL exposure to any single protocol
- **Idle buffer** — Minimum 20% TVL kept liquid for withdrawals  
- **Safety gates** — Runway and CR requirements before risk activities
- **Emergency controls** — Independent pause mechanisms for each module
- **Governance timelock** — Parameter changes subject to delay

---

## 5) Roadmap to Production

**Week 1-2: Core Infrastructure**
- Deploy vault, strategy, treasury contracts on Base testnet
- Build basic web interface for deposits/withdrawals  
- Implement DCA and transparency logging

**Week 3-4: Bond Program**  
- Deploy bond manager and ATN tranche contracts
- Add notes subscription interface
- Implement coverage ratio monitoring and gates

**Week 5-6: Buyback System**
- Deploy buyback contract with TWAP mechanisms
- Add AGN token and initial liquidity
- Test full flywheel with safety gates

**Week 7-8: Production Launch**
- Security audit and testing
- Mainnet deployment with conservative caps
- Community launch and initial user onboarding

---

**Agonic v1: Disciplined yield, ETH reserves, and mechanical token value accrual.**
