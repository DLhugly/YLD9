# Agonic v1 — One Killer Product

**Tagline:** *Deposit stables → earn conservative yield → protocol accumulates ETH (MicroStrategy-style) → disciplined $AGN buybacks governed by safety gates.*

No separate Taska or AgentPayy in v1. Task automation/attestations live **inside** Agonic as simple transparency events.

---

## 1) What ships on Day One

### 1.1 User experience

* **sUSD Vault (ERC-4626 / USDC only):** deposit/withdraw; we farm a **single, conservative** Base venue (no leverage).
* **ETH Reserve Transparency:** the Treasury DCA-buys ETH weekly; every trade logged on-chain & in the dashboard.
* **"ETH Boost" (optional):** depositors can take a slice of *their yield* in ETH (principal stays in USDC).
* **Agonic Treasury Notes (ATN):** fixed-APR USDC notes (non-transferable until maturity) to accelerate ETH accumulation.

### 1.2 Protocol flywheel (your TIP-11 merged)

* **Net Yield → Buybacks:** **40% of Net Yield (NY)** becomes the *Buyback Pool* (BP) **when safety gates are green**.
* **Buyback Split:** **50% burn / 50% to Treasury** (treasury-held AGN = long-term alignment).
* **LP staking later:** single-sided staking is **retired**; LP staking (AGN/ETH, AGN/USDC) comes **after** launch via AIP with tight caps.
* **POL & Bonding:** once KPIs are stable, enable bonding to grow protocol-owned liquidity.

---

## 2) Make the token valuable (MicroStrategy-style)

### 2.1 ETH balance-sheet playbook

* **Two ETH inflows:**

  1. A portion of **protocol fees on yield** (not principal).
  2. **ATN bond proceeds** (100% routed to ETH DCA per AIP-02).
* **Runway first:** keep ≥ **6 months OPEX** in USDC before any DCA or buybacks.
* **Coverage Ratio (CR) guard:**

  $$
  \mathrm{CR}=\frac{\text{Treasury USDC}+\text{Treasury ETH}\times\text{ETH/USD}}{\text{ATN Principal Outstanding}}
  $$

  Require **CR ≥ 1.2×**. If CR dips < 1.2× → **pause** new ATN issuance & buybacks automatically.

### 2.2 $AGN value drivers (no promises, just mechanics)

* **Programmatic Buybacks:** 40% of NY (when gates OK) buys AGN via TWAP/split orders → **50% burn / 50% treasury**.
* **Treasury Backing Metric:** publish **Treasury per Token (TPT)** weekly (purely informational).
* **Utility (non-rev share):**

  * Govern the **three scarce knobs**: feeBps, weekly DCA cap, buyback policy.
  * **Priority access** & better limits on ATN subscriptions.
  * **LP boosts** (once enabled) and **bonding discounts** (later).
  * **Protocol voting power** over venue caps/safety lights.
* **Supply:** **Fixed cap** (e.g., **200M AGN**). No emissions v1. Incentives (if any) come from **treasury-held AGN** via AIP.

---

## 3) Day-one parameters (can change via AIP)

| Parameter      | Initial                                                                                      |
| -------------- | -------------------------------------------------------------------------------------------- |
| Vault asset    | USDC (Base)                                                                                  |
| Strategy       | One safe venue (no leverage), venue cap ≤ **60% TVL**                                        |
| Idle buffer    | ≥ **20% TVL**                                                                                |
| Fee on Yield   | **12%** (never on principal)                                                                 |
| Runway buffer  | **6 months** OPEX (USDC)                                                                     |
| Weekly DCA cap | **$5,000** USDC (can scale with TVL)                                                        |
| Buyback pool   | **40% of NY** (gated)                                                                        |
| Buyback split  | **50% burn / 50% treasury**                                                                  |
| CR minimum     | **1.2×**                                                                                     |
| ATN-01 tranche | Cap **$250k**; **8% APR** weekly coupons; **6-month** term; non-transferable until maturity |

---

## 4) Contracts (minimal, auditable surfaces)

* **StableVault4626.sol** — ERC-4626 USDC vault; `deposit/withdraw/harvest()`. Takes **fee on yield only** and forwards to Treasury.
* **StrategyAdapter.sol** — one venue; `invest/divest/report()`.
* **Treasury.sol** — holds USDC/ETH, tracks **Runway** & **CR**; `weeklyDCA()`; emits `BuyEthExecuted(spentUSDC, receivedETH, price)`.
* **BondManager.sol + ATNTranche.sol** — fixed-APR USDC notes; `subscribe/payCoupons/redeem`; issuance auto-pauses if CR < 1.2×.
* **Buyback.sol** — TWAP/split orders, **≤10% of 30d DEX volume**, private relay flag; splits **50/50 burn/treasury**.
* **Gov.sol** — multisig + timelock; sets feeBps, DCA caps, buyback % & split, ATN params.
* **AttestationEmitter.sol (internal)** — emits transparency events (baseline/realized) for dashboard; no settlement gating.

---

## 5) Governance: your TIP-11 → Agonic AIP-01, plus AIP-02 bonds

* **AIP-01 — ETH Reserve & Yield Flywheel**
  40% of NY → buybacks (gated by Runway & CR); 50% burn / 50% treasury; single-sided staking sunset; LP staking framework defined but **OFF** at TGE; TWAP + volume caps.
* **AIP-02 — Agonic Treasury Notes (ATN) Program**
  Authorizes ATN; **Tranche 01**: $250k cap, 8% APR, 6m term, weekly coupons, proceeds 100% to ETH DCA; transfers disabled until maturity; CR & runway guards; weekly reporting.

> (Full AIP markdowns are at the end—paste into `/governance`.)

---

## 6) Roadmap to mainnet (4–8 weeks)

**Week 1–2 — Core rails**

* Deploy **Vault + StrategyAdapter** (Sepolia → Base canary), **Treasury** (runway/CR), **Gov**.
* Web: Deposit/Withdraw; APY; **Treasury ETH** chart; **DCA log**.

**Week 3 — Notes & policies**

* Deploy **BondManager + ATNTranche**; wire `payCoupons/redeem`.
* Publish **AIP-01/AIP-02**; parameterize for canary.
* Web: "Buy Notes" flow; coupon schedule; **CR light**.

**Week 4 — Canary mainnet**

* Vault TVL cap **$100–250k**; ATN-01 cap **$250k**.
* DCA small; **buybacks OFF** until Runway ≥ 6m & CR ≥ 1.2× for ≥ 2 weeks.

**Weeks 5–8 — Scale carefully**

* Raise caps; consider enabling **small buybacks** per AIP-01.
* Prepare LP staking AIP (OFF by default).
* Add second venue adapter (separate cap).

---

## 7) Dashboard (must-have tiles)

* **Your position:** shares, earned USDC/ETH, ETH Boost toggle.
* **Vault:** TVL; venue allocation; idle %; realized net APY.
* **Treasury:** ETH reserve over time; **BuyEthExecuted** log (block, route, price).
* **ATN:** outstanding principal; next coupon date/amount; coupons paid; **CR**.
* **Buybacks:** spent, AGN bought, burned, to-treasury; safety lights **RUNWAY_OK / CR_OK / BUYBACKS_ON**.

---

## 8) Risk & controls (plain English)

* **Principal safety:** only blue-chip, capped venues; no leverage; idle buffer.
* **Runway before risk:** we don't buy ETH or buy back AGN until runway is healthy.
* **CR discipline:** bonds auto-throttle buybacks/issuance if CR falls.
* **Emergency:** pause DCA/buybacks/notes independently; timelock awareness.
* **Compliance:** ATN may be securities—non-transferable until maturity; follow counsel.

---

## 9) Weekly runbooks

* **Harvest:** pull strategy yield → Vault → fee on yield → Treasury.
* **DCA:** once per week, `weeklyDCA()` with cap; record event.
* **Coupons:** call `payCoupons(trancheId)` weekly (ATN-01).
* **Reporting:** publish dashboard snapshot + on-chain tx bundle.

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

**Agonic v1 = one product:** stable yield, ETH reserve, and a disciplined token flywheel. No noise, just mechanics users can see.
