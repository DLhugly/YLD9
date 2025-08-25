# Agonic Phase 1 Final Implementation Plan

## Executive Summary
Complete Phase 1 with automation, LP staking, POL management, and hard-enforced safety gates. No token minting, no dilution, just disciplined execution.

---

## 1. Critical Path Items (Must Have)

### 1.1 Safety Gate Enforcement
**Priority: CRITICAL**
- Hard require() checks in Buyback.sol for runway ≥6m and CR ≥1.2×
- Liquidity threshold check (≥$50K pool depth) via DEX reserves
- 30-day volume cap enforcement (≤10% of rolling volume)
- Emit AttestationEmitter events on all state changes
- Add `getSafetyGateStatus()` view for UI/keepers

### 1.2 LP Staking Contract
**Priority: HIGH**
```solidity
contract LPStaking {
    // Aerodrome AGN/USDC LP token only for v1
    // Treasury-funded AGN rewards (no minting)
    // Weekly emission budget: 1000 AGN
    // Per-pool TVL cap: $500K
    // Per-user cap: $50K
    // Emergency pause and withdraw
}
```

### 1.3 POL Manager
**Priority: HIGH**
```solidity
contract POLManager {
    // Sources: treasury AGN + stable yield (never principal)
    // Target: Aerodrome AGN/USDC gauge
    // Daily add budget: $10K max
    // Target ownership: ≥33% of pool
    // Slippage protection: 1% max
    // IL tracking and reporting
}
```

### 1.4 Treasury Enhancements
**Priority: HIGH**
- Add TPT (Treasury per Token) calculation
- Weekly TPT publishing via AttestationEmitter
- ETH Boost option for vault depositors (yield split)
- Enforce idle buffer ≥20% TVL in TreasuryManager

### 1.5 Automation Registry
**Priority: MEDIUM**
```solidity
contract KeeperRegistry {
    // Gelato tasks for weekly operations
    // Dry-run simulation methods
    // Per-function circuit breakers
    // Gas price limits
    // Execution windows
}
```

---

## 2. Implementation Sequence

### Week 1: Safety Gates & Core Contracts
1. Update Buyback.sol with hard gates
2. Create LPStaking.sol contract
3. Create POLManager.sol contract
4. Add TPT metric to Treasury.sol
5. Write comprehensive tests

### Week 2: Automation & Integration
1. Deploy KeeperRegistry.sol
2. Configure Gelato tasks
3. Wire frontend components to contracts (wagmi/viem)
4. Add ETH Boost option to vault
5. Integration testing suite

### Week 3: Polish & Audit Prep
1. Gas optimizations
2. Slither static analysis
3. Invariant testing
4. Documentation updates
5. Deployment scripts

---

## 3. Contract Updates

### 3.1 Buyback.sol
```solidity
function executeBuyback(uint256 amount) external {
    // Hard gates
    require(getRunwayMonths() >= 6, "Runway < 6m");
    require(getCoverageRatio() >= 12000, "CR < 1.2x");
    require(getPoolLiquidity() >= 50000e6, "Liquidity < $50K");
    require(amount <= getVolumeLimit(), "Exceeds 30d volume cap");
    
    // Execute TWAP buyback
    uint256 agnBought = _executeTWAPBuyback(amount);
    
    // 50/50 split
    uint256 toBurn = agnBought / 2;
    uint256 toTreasury = agnBought - toBurn;
    
    // Burn
    IERC20(AGN).burn(toBurn);
    
    // Send to treasury
    IERC20(AGN).transfer(treasury, toTreasury);
    
    // Emit events
    attestationEmitter.emitBuybackExecuted(
        amount, agnBought, toBurn, toTreasury, block.timestamp
    );
}
```

### 3.2 Treasury.sol
```solidity
function calculateTPT() public view returns (uint256) {
    uint256 totalValue = getTreasuryValue(); // USDC + ETH * price
    uint256 circulatingSupply = getCirculatingSupply();
    return totalValue * 1e18 / circulatingSupply;
}

function publishTPT() external {
    uint256 tpt = calculateTPT();
    attestationEmitter.emitTPTPublished(tpt, block.timestamp);
}
```

### 3.3 TreasuryManager.sol
```solidity
function executeRebalancing(address asset, uint256 totalAmount) external {
    // Enforce idle buffer
    uint256 requiredIdle = (totalTVL * 2000) / 10000; // 20%
    require(getIdleBalance() >= requiredIdle, "Idle buffer < 20%");
    
    // Check APY deviation
    require(getMaxAPYDeviation() > 200, "Deviation < 2%");
    
    // Execute rebalancing...
}
```

---

## 4. Automation Configuration

### 4.1 Gelato Tasks
```javascript
// Weekly DCA - Monday 00:00 UTC
{
    name: "weeklyDCA",
    contract: treasury,
    function: "weeklyDCA()",
    schedule: "0 0 * * 1",
    gasLimit: 500000
}

// Weekly Buyback - Monday 12:00 UTC
{
    name: "executeBuyback",
    contract: buyback,
    function: "executeBuyback()",
    schedule: "0 12 * * 1",
    gasLimit: 1000000
}

// Weekly Coupons - Sunday 23:00 UTC
{
    name: "payCoupons",
    contract: bondManager,
    function: "payCoupons(uint256)",
    schedule: "0 23 * * 0",
    gasLimit: 800000
}

// Rebalancing - Check every 4 hours
{
    name: "checkAndRebalance",
    contract: treasuryManager,
    function: "executeRebalancing()",
    interval: 14400,
    gasLimit: 2000000
}
```

### 4.2 Safety Checks
All automated functions include:
- Pre-execution dry-run simulation
- Gas price limits (max 100 gwei)
- Slippage protection (max 1%)
- Daily/weekly spend caps
- Emergency pause capability

---

## 5. Frontend Integration

### 5.1 New Components
- LP Staking Dashboard (stake, rewards, APY)
- POL Manager UI (liquidity metrics, IL tracking)
- TPT Display (weekly history chart)
- Automation Status (next execution, gate status)

### 5.2 Wagmi/Viem Integration
Replace all mock data with contract reads:
- useContractRead for view functions
- useContractWrite for transactions
- useWaitForTransaction for confirmations
- useBalance for wallet balances

---

## 6. Testing Requirements

### 6.1 Unit Tests
- Safety gate enforcement edge cases
- LP staking reward calculations
- POL add/remove with slippage
- TPT calculation accuracy
- Automation trigger conditions

### 6.2 Integration Tests
- Full weekly cycle simulation
- Multi-protocol rebalancing
- FX arbitrage profitability
- Emergency pause procedures
- Gas optimization benchmarks

### 6.3 Invariant Tests
- Treasury value never decreases (except withdrawals)
- CR always ≥ 1.0 after operations
- Idle buffer maintained ≥ 20%
- No negative IL in POL
- TPT monotonically increasing

---

## 7. Risk Mitigations

### 7.1 Launch Caps
- LP staking: $500K TVL max
- POL daily add: $10K max
- FX arbitrage: $50K/day max
- Rebalancing: Once per day max

### 7.2 Emergency Controls
- Pause individual functions
- Withdraw POL to treasury
- Stop LP rewards distribution
- Halt automation tasks

### 7.3 Monitoring
- AttestationEmitter events indexed
- Subgraph for analytics
- Alerting on gate violations
- Daily health reports

---

## 8. Success Metrics

### Week 1 Post-Launch
- [ ] All safety gates enforcing correctly
- [ ] LP staking TVL > $100K
- [ ] POL ownership > 10%
- [ ] TPT published weekly
- [ ] Zero failed transactions

### Month 1 Post-Launch
- [ ] Vault TVL > $1M
- [ ] ATN subscriptions > $100K
- [ ] Weekly buybacks executing
- [ ] POL ownership > 20%
- [ ] All automation running smoothly

---

## 9. Deployment Checklist

### Pre-Deploy
- [ ] All contracts tested (100% coverage)
- [ ] Slither analysis clean
- [ ] Gas optimizations complete
- [ ] Deployment scripts ready
- [ ] Multisig configured

### Deploy Day
- [ ] Deploy contracts in order
- [ ] Configure all parameters
- [ ] Set up Gelato tasks
- [ ] Initialize LP pool
- [ ] Seed initial POL

### Post-Deploy
- [ ] Verify all contracts
- [ ] Test all functions
- [ ] Monitor first automation cycle
- [ ] Publish TPT
- [ ] Update documentation

---

## 10. Next Steps

1. **Immediate**: Implement safety gates in Buyback.sol
2. **Day 2-3**: Build LPStaking.sol and POLManager.sol
3. **Day 4-5**: Add TPT and automation registry
4. **Day 6-7**: Frontend integration and testing
5. **Week 2**: Full integration testing and audit prep

This plan delivers a complete, automated, and safe Phase 1 with no token dilution and disciplined execution.
