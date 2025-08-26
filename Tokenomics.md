```1:270:docs/Tokenomics.md
# Agonic Tokenomics Plan

## **Executive Summary**
The AGN token is designed to be the world's most sustainable DeFi governance token, backed by a pure ETH treasury and powered by an ultra-simple deflationary flywheel. With a **fixed supply of 200M tokens** and **zero emissions ever**, AGN derives value purely from protocol performance: simple USDC bonds fund pure ETH accumulation, core staking vault generates fees, which powers aggressive buybacks (80% burn for maximum scarcity, 20% treasury operations). Set-it-and-forget-it simplicity with Chainlink pricing and safety gates.

This plan optimizes for **long-term value accrual** over short-term hype:
- **Non-Inflationary**: No farming, no rebases—only burns reduce supply.
- **Treasury-Centric**: TPT (Treasury Per Token) metric ties AGN price to pure ETH backing.
- **Ultra-Simple Flywheel**: USDC bonds → ETH treasury → 80% burn AGN → maximum deflation.
- **Set and Forget**: Minimal complexity, maximum automation, Chainlink pricing.

At a $5-10M launch raise, this sets up a $5M+ ETH treasury from day one, generating $200-400K/year yield to kickstart the cycle. Projected 6-month TPT growth: 1.5-3x in base/bull cases.

---

## **1. Token Overview**
- **Token Name**: Agonic Token
- **Symbol**: AGN
- **Total Supply**: **200,000,000** (fixed cap, non-mintable)
- **Decimals**: 18
- **Blockchain**: Base L2 (Ethereum compatible)
- **Contract**: Gov.sol (governance) + AGN ERC-20 (minted at deploy, controlled by treasury/multisig)
- **Emissions**: **Zero** - No farming, staking rewards, or inflation. All incentives from treasury-held AGN or bonds.
- **Burn Mechanism**: Continuous via buybacks (50% of pool burns AGN, reducing circulating supply).
- **Deflationary Pressure**: Expected 2-5% annual supply reduction via burns (scales with yield).

**Core Thesis**: AGN is a **governance share of a productive ETH treasury**. Value grows as treasury accumulates ETH/fees, burns reduce supply, and AI optimizes efficiency. No "print and dump"—protocol success directly accrues to holders.

---

## **2. Token Distribution and Allocation**
To bootstrap liquidity and treasury without excessive dilution, we use a **fair launch model** with vested allocations. Total supply: 200M AGN.

### **Allocation Breakdown (Optimized for Sustainability)**
| Category          | Percentage | Amount (AGN) | Vesting/Cliffs | Description |
|-------------------|------------|--------------|----------------|-------------|
| **Public Sale/Launch** | 30% | 60M | 50% immediate, 50% 3-month linear vest | $5-10M raise at $0.1/AGN; proceeds → 100% ETH treasury. Vesting prevents dumps. |
| **Treasury Reserve** | 40% | 80M | Locked in Treasury.sol, released via governance | Funds future incentives, operations, and POL seeding. No auto-emissions—governed AIPs only. |
| **Team/Founders** | 15% | 30M | 1-year cliff, 2-year linear vest | Aligned long-term; multisig controlled. |
| **Advisors/Partners** | 5% | 10M | 6-month cliff, 18-month vest | For key contributors (e.g., auditors, launchpads). |
| **Liquidity Bootstrapping** | 5% | 10M | Immediate, but locked in POLManager.sol | Seeds AGN/USDC and AGN/ETH pools for initial depth. |
| **Community Incentives** | 5% | 10M | Governed releases over 2 years | Airdrops, bug bounties, or growth programs—zero pre-mined farming. |

### **Launch Mechanics**
- **Raise Target**: $5-10M via launchpad (e.g., Fjord on Base) at $0.1/AGN valuation.
- **Post-Raise**: Convert 100% proceeds to ETH via Treasury.weeklyDCA() (capped to avoid slippage).
- **Initial Circulating Supply**: ~40M (20%) after vesting unlocks—keeps FDV reasonable (~$20M at launch).
- **Vesting Enforcement**: Use simple timelock contracts or multisig with release schedules.

**Rationale**: Heavy treasury allocation (40%) ensures long-term funding without inflation. Vesting minimizes sell pressure, aligning all parties with TPT growth.

---

## **3. Token Utility and Value Drivers**
AGN is **not a yield token**—it's a governance asset with utility tied to protocol success. Zero emissions mean value comes from treasury growth and scarcity.

### **Core Utilities**
1. **Governance Locking (Via Gov.sol)**:
   - Lock AGN for time-weighted vote power (longer lock = more weight).
   - Vote on parameters (e.g., venue allocations, bond discounts, staking %).
   - **ROI**: Empowers holders to optimize the treasury (e.g., AI proposals need governance approval).

2. **Simple Bond Access (Via SimpleBond.sol)**:
   - Single USDC bonds with fixed 10% discount, 7-day vesting.
   - 100% proceeds → pure ETH treasury accumulation.
   - **ROI**: Direct ETH backing growth → TPT appreciation.

3. **Staking Vault Boosts (Via StakingVault.sol)**:
   - Locked AGN holders get +5% yield boost on USDC/ETH staking.
   - Boost funded from 20% of vault fees (self-sustaining).
   - **ROI**: At 8% base USDC yield, +5% boost = significant advantage for lockers.

4. **Ultra-Simple Deflationary Mechanisms**:
   - **Auto-Buybacks**: All inflows (bonds + staking fees) → Treasury.processInflow().
   - **Aggressive Split**: 80% burn AGN immediately, 20% treasury operations.
   - **Pure ETH Focus**: No complex POL management—treasury holds/stakes pure ETH via Lido.

### **Ultra-Simple Value Accrual Flywheel**
- **Bonds → ETH**: USDC bonds (10% discount) → 100% proceeds to pure ETH treasury.
- **Staking → Fees**: USDC/ETH staking vault (5% fee) → fees to treasury.
- **Inflows → Burns**: All inflows trigger automatic 80% AGN burns, 20% treasury.
- **ETH → TPT**: Pure ETH treasury growth drives TPT (Treasury Per Token) appreciation.
- **Set and Forget**: Chainlink pricing, safety gates, burn throttling—minimal intervention.

**TPT Metric (Treasury Per Token)**: Weekly published in Treasury.sol: `TPT = (Treasury Value) / (Circulating AGN)`. Burns decrease denominator; ETH growth increases numerator. AI forecasts TPT for user simulators.

---

## **4. Ultra-Simple Flywheel Mechanics (The Engine)**
The protocol generates sustainable value through minimal, automated systems:

1. **Simple USDC Bonds (SimpleBond.sol)**:
   - Deposits: USDC only → fixed 10% discount, 7-day linear vesting.
   - Proceeds: 100% converted to ETH treasury (no complex allocations).
   - Safety: Weekly caps, runway/CR gates, Chainlink pricing.

2. **Core Staking Vault (StakingVault.sol)**:
   - Assets: USDC (via Aave 8-12% APR) + ETH (via Lido ~4% APR).
   - Fees: 5% on yields → treasury for buybacks.
   - Boosts: AGN lockers get +5% yield (funded from 20% of fees).

3. **Pure ETH Treasury (Treasury.sol)**:
   - Holdings: 100% ETH (liquid + staked via Lido).
   - Inflows: Bond proceeds + staking fees via processInflow().
   - Auto-Buybacks: 80% burn AGN, 20% treasury operations.

4. **Automatic Buybacks (Buyback.sol)**:
   - Trigger: All inflows automatically execute buybacks.
   - Execution: 3-day TWAP with safety gates and burn throttling.
   - Split: 80% burn (maximum deflation), 20% treasury (operations).

**Ultra-Simple Economic Model at $5M Launch + $2M Staking TVL**:
- Treasury ETH Yield: $200K/year (4% on $5M ETH).
- Staking Vault Fees: $10K/year (5% fee on $200K gross yield).
- Total Inflows: $210K/year.
- AGN Burns: $168K/year (80% of inflows) → 3-8% supply reduction.
- Treasury Operations: $42K/year (20% of inflows) → sustainable ops funding.

---

## **5. Governance and Upgrades**
- **Gov.sol**: AGN holders lock for vote weight (time-weighted: longer lock = more power).
- **Scope**: Parameters (e.g., fees, caps, discounts) via AIPs; treasury spending requires quorum.
- **AI Integration**: Proposals from AI oracle need governance ratification for key changes.
- **Upgrades**: Timelocked multisig for contracts; community veto on critical params.

---

## **6. Risks and Mitigations**
- **Dilution Risk**: Fixed supply + vesting → no inflation.
- **Liquidity Risk**: POL targets + seeded pools → min $50K depth for buybacks.
- **Yield Risk**: Diversified venues + gates → pause if low.
- **Smart Contract Risk**: 100% test coverage; audits before launch.
- **Market Risk**: ETH volatility hedged by stables buffer; CR enforces overcollateralization.

---

## **7. Conclusion: Why This is the World's Simplest & Best Tokenomics**
This plan creates **intrinsic, compounding value** through ultra-simple mechanics: a fixed-supply token backed by pure ETH treasury, fueled by USDC bonds and staking fees, with aggressive 80% burns for maximum deflation. It's resilient (safety gates), ultra-simple (no complex POL), and scalable (L2 + minimal contracts). Launch with $5-10M, bootstrap pure ETH treasury, and let automatic buybacks drive AGN scarcity.

**Set it and forget it**: The ultimate sustainable treasury protocol.
```