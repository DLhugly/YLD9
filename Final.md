1. Objectives
1.1 Maximize protocol net asset value in ETH and stablecoins.
1.2 Maximize native token value via sustained buybacks and controlled burns.
1.3 Grow deep, resilient native/USDC liquidity with low IL risk.
1.4 Maintain solvency and runway through dynamic, rules-based allocation.

2. Assets and roles
2.1 Stablecoins: intake currency, runway buffer, yield on Aave, LP pairing leg.
2.2 ETH: balance-sheet asset, staked on Lido for yield, price beta.
2.3 Native token: buyback target, burn subject, LP pairing leg, governance utility.

3. Inflow sources
3.1 Bonds: USDC-only deposits, discounted native token issuance, 100% USDC to treasury router.
3.2 Staking fees: 5% fee on user yield (USDC leg), streamed to treasury router.
3.3 LP fees: native/USDC pool fee income (USDC and native token), routed through treasury router.
3.4 ETH staking rewards: stETH growth harvested to treasury router.

4. State variables and gates
4.1 Coverage ratio CR = total_treasury_value / native_circulating_value; gate high when CR ≥ 1.2×.
4.2 Runway R_months ≥ 6; gate high when runway meets or exceeds threshold.
4.3 Pool depth D_pool (USD) vs D_min = 50,000 and D_target (governed); gate low when D_pool < D_min, medium when D_min ≤ D_pool < D_target.
4.4 Daily execution budgets: caps for DCA, LP adds, and buybacks (governed).

5. Router policy (per USDC inflow cycle)
5.1 Compute gates {CR, R_months, D_pool}.
5.2 Set burnBPS = 8000 when CR ≥ 1.2× and R_months ≥ 6, else burnBPS = 5000.
5.3 Stable reserve top-up first: route inflow to stable buffer until R_months ≥ 6; if under target, all residual actions throttle proportionally.
5.4 Liquidity deficit handling: if D_pool < D_min, pre-allocate LP_pair_budget from the “treasury share” of buybacks (section 6) and match with USDC from inflow; if D_min ≤ D_pool < D_target, allocate fractionally; if D_pool ≥ D_target, LP_pair_budget = 0.
5.5 Residual inflow split after 5.3–5.4: route remainder to ETH DCA (section 7) and fee wallet (stable reserve) per governed weights with TWAP execution.

6. Buyback and post-buyback allocation
6.1 Execute native buyback via 3-day TWAP with min-out and venue routing; input source = ETH or USDC per price and slippage policy.
6.2 Split native bought: burn = burnBPS; non-burn = (10000 − burnBPS).
6.3 When D_pool < D_target, redirect up to 100% of non-burn to LP pairing with USDC to mint POL; when D_pool ≥ D_target, route non-burn to treasury reserve (no net emissions).
6.4 Enforce daily buyback caps and pause on oracle deviation, pool liquidity shortfall, or price impact breach.

7. ETH accumulation and staking
7.1 Convert USDC_to_ETH via TWAP DCA respecting daily cap and slippage limit.
7.2 Stake ETH on Lido up to governed staking ratio; maintain liquid ETH buffer for buybacks, LP pairing, and operations.
7.3 Harvest stETH growth periodically and route to 5.x with the same gates.

8. Stablecoin accumulation and yield
8.1 Maintain stable runway buffer ≥ 6 months; if below threshold, prioritize stable accumulation over ETH buys and LP growth.
8.2 Deposit excess stables to Aave v3; accrue interest and route harvests through 5.x.
8.3 All protocol fees, LP fee USDC leg, and staking fee USDC leg accrue to stable reserve before re-allocation.

9. Liquidity growth and IL control
9.1 Provide POL to native/USDC pool only when D_pool < D_target; use symmetric adds with TWAP and time-staggering to reduce MEV.
9.2 Source USDC leg from inflows; source native leg from buybacks’ non-burn portion; never mint native to pair.
9.3 Enforce daily LP add cap, minimum pool liquidity guard, and remove/add cool-down windows; no LP additions when CR < 1.2× or R_months < 6 unless D_pool < D_min.

10. Burn throttle and safety
10.1 Burn throttle: burnBPS = 8000 when CR ≥ 1.2× and R_months ≥ 6, else 5000.
10.2 Circuit breakers: pause buybacks, LP adds, and ETH DCA on oracle deviation, pool liquidity below threshold, abnormal price impact, or governance pause.
10.3 Always preserve runway ≥ 6 months by diverting inflows to stables when breached.

11. Execution order per cycle
11.1 Top-up stable runway buffer to ≥ 6 months.
11.2 Compute LP_pair_budget and perform LP adds if D_pool < thresholds (TWAP).
11.3 Execute buyback (TWAP); apply burn and LP pairing or treasury reserve per 6.x.
11.4 Execute ETH DCA (TWAP) and stake per buffer ratios.
11.5 Deposit excess stables to Aave; queue next cycle.

12. Cashflow outcomes
12.1 Stablecoins increase via bond intake, fee skims, LP fees (USDC leg), and Aave yields; priority to maintain runway, then compounding.
12.2 ETH balance sheet compounds through DCA and staking rewards; supports valuations and buyback firepower.
12.3 Native token supply declines through continuous buybacks and burns; liquidity deepens via non-burn pairing, improving price integrity and slippage.

13. Governance levers (parameterized, on-chain)
13.1 burnBPS high/low thresholds; CR and runway thresholds (CR ≥ 1.2×, runway ≥ 6).
13.2 D_min and D_target; daily caps for buybacks, LP adds, and DCA.
13.3 Staking ratios (ETH staked vs liquid), stable runway target, Aave deposit caps.
13.4 Oracle sources, TWAP window, slippage limits, venue routing.

14. KPIs
14.1 Stable runway months, stable reserve size, Aave effective APY.
14.2 ETH holdings, stETH yield realized, DCA execution quality.
14.3 Native supply burned, buyback efficiency (slippage, impact), LP depth and pool ownership.
14.4 Coverage ratio CR, TPT trend, fail-safe triggers and downtime.

15. Rationale
15.1 Defaults maximize stability first (runway), market integrity next (LP), and growth last (ETH DCA), with burns throttled by solvency, ensuring durable token appreciation and compounding reserves without overexposing to IL or price shocks.