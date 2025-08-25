# Agonic v1 — One Killer Product

**Tagline:** *Deposit stables → earn conservative yield → protocol accumulates ETH (MicroStrategy-style) → disciplined $AGN buybacks governed by safety gates.*

No separate Taska or AgentPayy in v1. Task automation/attestations live **inside** Agonic as simple transparency events.

---

## 1) What ships on Day One

### 1.1 User experience

1. **Multi-Stablecoin Vault (ERC-4626):** deposit/withdraw USDC, USD1, EURC; automated rebalancing across **proven Base protocols** (Aave, WLF, Uniswap V3, Aerodrome) with allocation caps.
2. **ETH Reserve Transparency:** the Treasury DCA-buys ETH weekly via optimal routing; every trade and rebalancing action logged on-chain & in the dashboard.
3. **"ETH Boost" (optional):** depositors can take a slice of *their yield* in ETH (principal stays in stablecoins).
4. **FX Arbitrage Integration:** capture basis differentials across EURC/USDC/USD1 pairs to enhance vault yield.
5. **Agonic Treasury Notes (ATN):** fixed-APR multi-stablecoin notes (non-transferable until maturity) to accelerate ETH accumulation.

### 1.2 Protocol flywheel (your TIP-11 merged)

1. **Net Yield → Buybacks:** **40% of Net Yield (NY)** becomes the *Buyback Pool* (BP) **when safety gates are green**.
2. **Buyback Split:** **50% burn / 50% to Treasury** (treasury-held AGN = long-term alignment).
3. **LP staking later:** single-sided staking is **retired**; LP staking (AGN/ETH, AGN/USDC) comes **after** launch via AIP with tight caps.
4. **POL & Bonding:** once KPIs are stable, enable bonding to grow protocol-owned liquidity. **Target ≥33%** of main LP positions owned by Treasury.

---

## 2) Make the token valuable (MicroStrategy-style)

### 2.1 ETH balance-sheet playbook

1. **Two ETH inflows:**
   - A portion of **protocol fees on yield** (not principal).
   - **ATN bond proceeds** (100% routed to ETH DCA automatically).
2. **Runway first:** keep ≥ **6 months OPEX** in USDC before any DCA or buybacks.
3. **Coverage Ratio (CR) guard:**

  $$
  \mathrm{CR}=\frac{\text{Treasury USDC}+\text{Treasury ETH}\times\text{ETH/USD}}{\text{ATN Principal Outstanding}}
  $$

  Require **CR ≥ 1.2×**. If CR dips < 1.2× → **pause** new ATN issuance & buybacks automatically.

### 2.2 $AGN value drivers (no promises, just mechanics)

1. **Programmatic Buybacks:** 40% of NY (when gates OK) buys AGN via TWAP/split orders → **50% burn / 50% treasury**.
2. **Treasury Backing Metric:** publish **Treasury per Token (TPT)** weekly (purely informational).
3. **Utility (non-rev share):**
   - Govern the **three scarce knobs**: feeBps, weekly DCA cap, buyback policy.
   - **Priority access** & better limits on ATN subscriptions.
   - **LP staking rewards** (once enabled) and **bonding discounts** (later).
   - **Protocol voting power** over venue caps/safety lights.
4. **Supply:** **Fixed cap** (e.g., **200M AGN**). No emissions v1. Incentives (if any) come from **treasury-held AGN** via AIP.

---

## 3) Day-one parameters (can change via AIP)

| Parameter           | Initial                                                                                      |
| ------------------- | -------------------------------------------------------------------------------------------- |
| Vault assets        | USDC, USD1, EURC (Base L2)                                                                  |
| Base strategy       | Aave v3 lending (guaranteed yield floor)                                                     |
| Protocol allocation | Max caps: Aave ≤ **60% TVL**, WLF ≤ **40% TVL**, LP strategies ≤ **30% TVL** each           |
| Idle buffer         | ≥ **20% TVL** across all stablecoins                                                        |
| Fee on Yield        | **12%** (never on principal)                                                                 |
| Runway buffer       | **6 months** OPEX (USDC)                                                                     |
| Weekly DCA cap      | **$5,000** USDC (can scale with TVL)                                                        |
| FX arbitrage threshold | **0.1%** minimum price deviation to trigger automatic execution                             |
| ETH staking allocation | **≤20%** of treasury ETH (Lido/Rocket Pool integration)                                     |
| Buyback pool        | **40% of NY** (gated)                                                                        |
| Buyback frequency   | **Weekly** (aligned with DCA schedule)                                                       |
| Buyback split       | **50% burn / 50% treasury**                                                                  |
| Liquidity threshold | **$50K** minimum pool depth                                                                  |
| Volume cap          | **≤10%** of 30-day DEX volume                                                                |
| CR minimum          | **1.2×**                                                                                     |
| POL target          | **≥33%** of main LP positions (future)                                                       |
| ATN-01 tranche      | Cap **$250k**; **8% APR** weekly coupons; **6-month** term; non-transferable until maturity |
| LP staking pool     | Aerodrome **AGN/USDC** only (v1)                                                            |
| LP rewards budget   | **1000 AGN/week** from treasury (no minting)                                               |
| LP pool cap         | **$500K** TVL max                                                                           |
| POL daily budget    | **$10K** max add per day                                                                    |
| Keeper provider     | **Gelato** on Base (Chainlink backup)                                                       |
| TPT publish freq    | **Weekly** via AttestationEmitter                                                           |

---

## 4) Contracts (minimal, auditable surfaces)

1. **StableVault4626.sol** — Multi-asset ERC-4626 vault (USDC/USD1/EURC); `deposit/withdraw/harvest()`. Takes **fee on yield only** and forwards to Treasury. **ETH Boost option** for yield splitting.
2. **TreasuryManager.sol** — Multi-protocol rebalancing controller; dynamically allocates across Aave, WLF, Uniswap V3, Aerodrome based on risk-adjusted yields. **Enforces idle buffer ≥20% TVL**.
3. **Protocol Adapters:**
   - **AaveAdapter.sol** — Aave v3 lending integration for yield floor
   - **WLFAdapter.sol** — World Liberty Financial vault integration  
   - **UniswapAdapter.sol** — Uniswap V3 concentrated liquidity management
   - **AerodromeAdapter.sol** — Aerodrome stable LP strategies
4. **Treasury.sol** — holds multi-stablecoin/ETH, FX arbitrage execution, **ETH staking integration**, tracks **Runway** & **CR**; `weeklyDCA()` + `executeFXArbitrage()` + `stakeETH()`. **Computes and publishes TPT metric weekly**.
5. **BondManager.sol + ATNTranche.sol** — fixed-APR multi-stablecoin notes; `subscribe/payCoupons/redeem`; **hard-enforced CR ≥ 1.2× gate** for issuance and coupons.
6. **Buyback.sol** — **Weekly** TWAP/split orders with **hard-enforced safety gates** (runway ≥6m, CR ≥1.2×, liquidity ≥$50K, volume ≤10% 30d); splits **50/50 burn/treasury**.
7. **Gov.sol** — AGN holder + LP staker governance; LP stakers can vote on protocol integrations and high-risk strategies.
8. **AttestationEmitter.sol** — emits strategy performance and rebalancing events for full transparency.
9. **LPStaking.sol** — Aerodrome AGN/USDC LP rewards; treasury-funded AGN emissions (no minting); per-pool caps and weekly budget.
10. **POLManager.sol** — Protocol-owned liquidity for AGN/USDC; sources from treasury AGN + stable yield; targets ≥33% pool ownership.
11. **KeeperRegistry.sol** — Gelato/Chainlink automation registry for weekly ops with dry-run simulations.

---

## 5) Single Build Deployment

**Complete Day One Launch:**

1. **Full Protocol Suite**: Deploy all contracts simultaneously on Base L2
   - Multi-asset vault (USDC/USD1/EURC) with protocol integrations
   - Treasury with ETH DCA and FX arbitrage capabilities  
   - ATN bond system with automated coupon payments
   - Buyback mechanism with safety gate logic (enabled when conditions met)
   - Governance contracts with dual voting (AGN + LP stakers)

2. **Complete Web Interface**:
   - Multi-asset deposit/withdraw with **personalized yield simulator** and real-time APY comparison
   - Treasury dashboard with ETH accumulation, **staking rewards**, and **automated FX arbitrage** tracking
   - ATN subscription flow with coupon schedules and CR monitoring
   - Buyback status with safety gate indicators and TPT metrics
   - Protocol allocation breakdown across all integrated venues

3. **Conservative Launch Parameters**:
   - Initial TVL caps per protocol for safety
   - ATN bond cap for first tranche
   - Buyback mechanism armed but gated (activates automatically when runway ≥6m & CR ≥1.2× consistently)
   - LP staking framework contracts deployed but disabled pending governance activation

---

## 6) Dashboard (must-have tiles)

1. **Your position:** shares, earned yield by stablecoin, ETH Boost toggle, **personalized yield simulator** (deposit amount → projected monthly yield + ETH boost split using real-time APY from `quote/route.ts`), LP staking status (if applicable).
2. **Vault:** Total TVL by asset (USDC/USD1/EURC); protocol allocation breakdown (Aave/WLF/Uniswap/Aerodrome); idle % by stablecoin; realized net APY per protocol.
3. **Treasury:** ETH reserve over time; **staked ETH rewards**; **BuyEthExecuted** + **FXArbitrageExecuted** logs with routing details; **automated FX thresholds** status.
4. **ATN:** outstanding principal by stablecoin; next coupon date/amount; coupons paid; **CR**.
5. **Buybacks:** weekly execution log, AGN bought/burned/treasury; **liquidity depth check**; LP governance participation; safety lights **RUNWAY_OK / CR_OK / BUYBACKS_ON**; **TPT metric**.
6. **Strategy Performance:** Real-time APY comparison across protocols; rebalancing history; **automated FX arbitrage** profit tracking; **ETH staking yields**.

---

## 7) Risk & controls (plain English)

1. **Principal safety:** only blue-chip, capped venues; no leverage; idle buffer.
2. **Runway before risk:** we don't buy ETH or buy back AGN until runway is healthy.
3. **CR discipline:** bonds auto-throttle buybacks/issuance if CR falls.
4. **Emergency:** pause DCA/buybacks/notes independently; timelock awareness.
5. **Compliance:** ATN may be securities—non-transferable until maturity; follow counsel.

---

## 8) Automation & Weekly Operations

### 8.1 Automated via Gelato (permissionless but gated)
1. **weeklyDCA()** — Every Monday 00:00 UTC; capped at $5K; requires runway ≥6m
2. **executeBuyback()** — Every Monday 12:00 UTC; requires all gates green (runway, CR, liquidity, volume)
3. **payCoupons(trancheId)** — Every Sunday 23:00 UTC; auto-pauses if CR < 1.2×
4. **executeRebalancing()** — When APY deviation > 2% or allocation drift > 5%; max once daily
5. **executeFXArbitrage()** — When price deviation > 0.1%; max $50K/day; slippage cap 0.5%
6. **publishTPT()** — Every Sunday 22:00 UTC; emits Treasury-per-Token metric

### 8.2 Manual operations (owner/multisig)
1. **LP rewards config** — Set weekly AGN budget and pool allocPoints
2. **POL adds** — Execute strategic liquidity adds within daily budget
3. **Emergency pause** — Circuit breakers for each automated function
4. **ETH staking** — Manual provider selection (defer to Phase 2)

---

## 9) Repo structure (ready to scaffold)

```
agonic/
├─ apps/
│  ├─ web/                 # Vault, Treasury, Notes, Dashboard
│  └─ ops/                 # runbooks, scripts
├─ packages/
│  ├─ protocol/
│  │  ├─ StableVault4626.sol
│  │  ├─ StrategyAdapter.sol
│  │  ├─ Treasury.sol
│  │  ├─ BondManager.sol
│  │  ├─ ATNTranche.sol
│  │  ├─ Buyback.sol
│  │  └─ Gov.sol
│  └─ engine/
│     ├─ AttestationEmitter.sol   # events-only transparency
│     └─ sdk/ (ts)                # tiny client for the web app
└─ governance/
   └─ future-proposals/       # Directory for community AIPs
```

---

**Agonic v1 = one product:** stable yield, ETH reserve, and a disciplined token flywheel. No noise, just mechanics users can see.
