# Agonic v1 — One Killer Product

**Tagline:** *Deposit stables → earn conservative yield → protocol accumulates ETH (MicroStrategy-style) → disciplined $AGN buybacks governed by safety gates.*

No separate Taska or AgentPayy in v1. Task automation/attestations live **inside** Agonic as simple transparency events.

---

## 1) What ships on Day One

### 1.1 User experience

1. **sUSD Vault (ERC-4626 / USDC only):** deposit/withdraw; we farm a **single, conservative** Base venue (no leverage).
2. **ETH Reserve Transparency:** the Treasury DCA-buys ETH weekly; every trade logged on-chain & in the dashboard.
3. **"ETH Boost" (optional):** depositors can take a slice of *their yield* in ETH (principal stays in USDC).
4. **Agonic Treasury Notes (ATN):** fixed-APR USDC notes (non-transferable until maturity) to accelerate ETH accumulation.

### 1.2 Protocol flywheel (your TIP-11 merged)

1. **Net Yield → Buybacks:** **40% of Net Yield (NY)** becomes the *Buyback Pool* (BP) **when safety gates are green**.
2. **Buyback Split:** **50% burn / 50% to Treasury** (treasury-held AGN = long-term alignment).
3. **LP staking later:** single-sided staking is **retired**; LP staking (AGN/ETH, AGN/USDC) comes **after** launch via AIP with tight caps. **Optional ve-style boosts** (longer locks → higher rewards) for enhanced tokenomics.
4. **POL & Bonding:** once KPIs are stable, enable bonding to grow protocol-owned liquidity. **Target ≥33%** of main LP positions owned by Treasury.

---

## 2) Make the token valuable (MicroStrategy-style)

### 2.1 ETH balance-sheet playbook

1. **Two ETH inflows:**
   - A portion of **protocol fees on yield** (not principal).
   - **ATN bond proceeds** (100% routed to ETH DCA per AIP-02).
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
   - **LP boosts** (once enabled) and **bonding discounts** (later).
   - **Protocol voting power** over venue caps/safety lights.
4. **Supply:** **Fixed cap** (e.g., **200M AGN**). No emissions v1. Incentives (if any) come from **treasury-held AGN** via AIP.

---

## 3) Day-one parameters (can change via AIP)

| Parameter           | Initial                                                                                      |
| ------------------- | -------------------------------------------------------------------------------------------- |
| Vault asset         | USDC (Base)                                                                                  |
| Strategy            | One safe venue (no leverage), venue cap ≤ **60% TVL**                                        |
| Idle buffer         | ≥ **20% TVL**                                                                                |
| Fee on Yield        | **12%** (never on principal)                                                                 |
| Runway buffer       | **6 months** OPEX (USDC)                                                                     |
| Weekly DCA cap      | **$5,000** USDC (can scale with TVL)                                                        |
| Buyback pool        | **40% of NY** (gated)                                                                        |
| Buyback frequency   | **Weekly** (aligned with DCA schedule)                                                       |
| Buyback split       | **50% burn / 50% treasury**                                                                  |
| Liquidity threshold | **$50K** minimum pool depth                                                                  |
| Volume cap          | **≤10%** of 30-day DEX volume                                                                |
| CR minimum          | **1.2×**                                                                                     |
| POL target          | **≥33%** of main LP positions (future)                                                       |
| ATN-01 tranche      | Cap **$250k**; **8% APR** weekly coupons; **6-month** term; non-transferable until maturity |

---

## 4) Contracts (minimal, auditable surfaces)

1. **StableVault4626.sol** — ERC-4626 USDC vault; `deposit/withdraw/harvest()`. Takes **fee on yield only** and forwards to Treasury.
2. **StrategyAdapter.sol** — one venue; `invest/divest/report()`.
3. **Treasury.sol** — holds USDC/ETH, tracks **Runway** & **CR**; `weeklyDCA()`; emits `BuyEthExecuted(spentUSDC, receivedETH, price)`.
4. **BondManager.sol + ATNTranche.sol** — fixed-APR USDC notes; `subscribe/payCoupons/redeem`; issuance auto-pauses if CR < 1.2×.
5. **Buyback.sol** — **Weekly** TWAP/split orders, **≤10% of 30d DEX volume**, minimum pool depth **$50K**, private relay flag; splits **50/50 burn/treasury**.
6. **Gov.sol** — multisig + timelock; sets feeBps, DCA caps, buyback % & split, ATN params.
7. **AttestationEmitter.sol (internal)** — emits transparency events (baseline/realized) for dashboard; no settlement gating.

---

## 5) Governance: your TIP-11 → Agonic AIP-01, plus AIP-02 bonds

1. **AIP-01 — ETH Reserve & Yield Flywheel**
  40% of NY → buybacks (gated by Runway & CR); 50% burn / 50% treasury; single-sided staking sunset; LP staking framework defined but **OFF** at TGE; TWAP + volume caps.
2. **AIP-02 — Agonic Treasury Notes (ATN) Program**
  Authorizes ATN; **Tranche 01**: $250k cap, 8% APR, 6m term, weekly coupons, proceeds 100% to ETH DCA; transfers disabled until maturity; CR & runway guards; weekly reporting.

> (Full AIP markdowns are at the end—paste into `/governance`.)

---

## 6) Roadmap to mainnet (4–8 weeks)

**Week 1–2 — Core rails**

1. Deploy **Vault + StrategyAdapter** (Sepolia → Base canary), **Treasury** (runway/CR), **Gov**.
2. Web: Deposit/Withdraw; APY; **Treasury ETH** chart; **DCA log**.

**Week 3 — Notes & policies**

1. Deploy **BondManager + ATNTranche**; wire `payCoupons/redeem`.
2. Publish **AIP-01/AIP-02**; parameterize for canary.
3. Web: "Buy Notes" flow; coupon schedule; **CR light**.

**Week 4 — Canary mainnet**

1. Vault TVL cap **$100–250k**; ATN-01 cap **$250k**.
2. DCA small; **buybacks OFF** until Runway ≥ 6m & CR ≥ 1.2× for ≥ 2 weeks.

**Weeks 5–8 — Scale carefully**

1. Raise caps; consider enabling **small buybacks** per AIP-01.
2. Prepare LP staking AIP (OFF by default).
3. Add second venue adapter (separate cap).

---

## 7) Dashboard (must-have tiles)

1. **Your position:** shares, earned USDC/ETH, ETH Boost toggle.
2. **Vault:** TVL; venue allocation; idle %; realized net APY.
3. **Treasury:** ETH reserve over time; **BuyEthExecuted** log (block, route, price).
4. **ATN:** outstanding principal; next coupon date/amount; coupons paid; **CR**.
5. **Buybacks:** weekly execution log, AGN bought/burned/treasury; **liquidity depth check**; safety lights **RUNWAY_OK / CR_OK / BUYBACKS_ON**; **TPT metric**.

---

## 8) Risk & controls (plain English)

1. **Principal safety:** only blue-chip, capped venues; no leverage; idle buffer.
2. **Runway before risk:** we don't buy ETH or buy back AGN until runway is healthy.
3. **CR discipline:** bonds auto-throttle buybacks/issuance if CR falls.
4. **Emergency:** pause DCA/buybacks/notes independently; timelock awareness.
5. **Compliance:** ATN may be securities—non-transferable until maturity; follow counsel.

---

## 9) Weekly runbooks

1. **Harvest:** pull strategy yield → Vault → fee on yield → Treasury.
2. **DCA:** once per week, `weeklyDCA()` with cap; record event.
3. **Buybacks:** execute weekly TWAP orders when safety gates green; split 50/50 burn/treasury.
4. **Coupons:** call `payCoupons(trancheId)` weekly (ATN-01).
5. **Reporting:** publish dashboard snapshot + on-chain tx bundle; update TPT metric.

---

## 10) Repo structure (ready to scaffold)

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
   ├─ AIP-01_ETH_Reserve_Yield_Flywheel.md
   └─ AIP-02_Agonic_Treasury_Notes_Tranche01.md
```

---

## **Appendix: ve-Style Boosts (Optional Future Enhancement)**

**What are ve-style boosts?**
1. Users lock AGN tokens for different time periods (1 week to 4 years)
2. Longer locks get higher LP staking reward multipliers
3. Example: 1 week lock = 1.0× rewards, 4 year lock = 2.5× rewards
4. Reduces sell pressure and rewards long-term holders

**Implementation (if desired):**
1. Deploy veAGN contract alongside LP staking
2. Lock mechanism: Users choose duration, get voting power + reward multiplier
3. Benefits: Lower token velocity, stronger governance alignment, higher APRs for committed users

**Decision:** Optional. Can launch LP staking without ve-boosts initially and add later via AIP.

---

**Agonic v1 = one product:** stable yield, ETH reserve, and a disciplined token flywheel. No noise, just mechanics users can see.
