# Agonic Phase 1 Ultra-Simple Implementation Plan

## Executive Summary
Complete Phase 1 with ultra-simple bonds, core staking vault, pure ETH treasury, and automatic buybacks. No complex POL, no LP staking, no dynamic rebalancing—just disciplined execution with 80% burns.

---

## 1. Core Implementation (Must Have)

### 1.1 SimpleBond.sol
**Priority: CRITICAL**
```solidity
contract SimpleBond {
    // USDC-only bonds with fixed 10% discount
    // 7-day linear vesting
    // 100% proceeds to Treasury for ETH buys
    // Weekly cap: 100K AGN issuance
    // Safety gates: CR ≥1.2×, runway ≥6m
}
```

### 1.2 StakingVault.sol  
**Priority: CRITICAL**
```solidity
contract StakingVault {
    // ERC-4626 for USDC/ETH staking
    // 5% fee on yields (not principal)
    // AGN lockers get +5% boost
    // Fixed Aave for USDC (8-12% APR)
    // Lido for ETH (~4% APR)
    // Weekly fee distribution to buybacks
}
```

### 1.3 Treasury.sol Updates
**Priority: CRITICAL**
- Auto-buyback pipe with safety gates
- 80% burn / 20% treasury split on all inflows
- Chainlink ETH/USD pricing (no manual updates)
- Burn throttle: 50% if runway/CR low, else 80%
- Weekly TPT (Treasury Per Token) publishing

### 1.4 Buyback.sol Updates
**Priority: CRITICAL**
```solidity
function executeBuyback(uint256 amount) external {
    // Hard safety gates
    require(getRunwayMonths() >= 6, "Runway < 6m");
    require(getCoverageRatio() >= 1.2e18, "CR < 1.2x");
    require(getPoolLiquidity() >= 50000e6, "Pool < $50K");
    
    // Execute 3-day TWAP buyback
    uint256 agnBought = _executeTWAPBuyback(amount);
    
    // 80/20 split
    uint256 toBurn = (agnBought * 8000) / 10000; // 80%
    uint256 toTreasury = agnBought - toBurn;     // 20%
    
    // Burn AGN
    IERC20(AGN).burn(toBurn);
    
    // Send to treasury
    IERC20(AGN).transfer(treasury, toTreasury);
    
    // Emit transparency events
    attestationEmitter.emitBuybackExecuted(
        amount, agnBought, toBurn, toTreasury, block.timestamp
    );
}
```

---

## 2. Implementation Sequence (2 Days)

### Day 1: Core Contracts
1. **SimpleBond.sol** — USDC bonds with fixed discount and vesting
2. **StakingVault.sol** — USDC/ETH vault with AGN boosts  
3. **Update Treasury.sol** — Auto-buyback pipe and Chainlink pricing
4. **Update Buyback.sol** — 80/20 split and safety gates
5. **Comprehensive Tests** — Unit and integration testing

### Day 2: Integration & Deployment
1. **AaveAdapter.sol** — Fixed USDC lending integration
2. **LidoAdapter.sol** — ETH staking integration
3. **Frontend Updates** — Bond and staking interfaces
4. **Integration Testing** — Full system testing
5. **Mainnet Deployment** — With conservative parameters

---

## 3. Contract Architecture

### 3.1 SimpleBond.sol
```solidity
contract SimpleBond {
    IERC20 public immutable USDC;
    IERC20 public immutable AGN;
    ITreasury public immutable treasury;
    
    uint256 public constant DISCOUNT_BPS = 1000; // 10%
    uint256 public constant VESTING_DAYS = 7;
    uint256 public constant WEEKLY_CAP = 100000e18; // 100K AGN
    
    struct Bond {
        uint256 amount;        // AGN amount
        uint256 vestingStart;  // Start timestamp
        uint256 claimed;       // Already claimed
    }
    
    mapping(address => Bond[]) public userBonds;
    uint256 public weeklyIssued;
    uint256 public weekStart;
    
    function deposit(uint256 usdcAmount) external {
        // Safety gates
        require(treasury.getRunwayMonths() >= 6, "Runway < 6m");
        require(treasury.getCoverageRatio() >= 1.2e18, "CR < 1.2x");
        
        // Weekly cap check
        if (block.timestamp >= weekStart + 7 days) {
            weekStart = block.timestamp;
            weeklyIssued = 0;
        }
        
        // Calculate discounted AGN amount
        uint256 agnPrice = treasury.getAGNPrice();
        uint256 agnAmount = (usdcAmount * 1e18 * 10000) / (agnPrice * 9000); // 10% discount
        
        require(weeklyIssued + agnAmount <= WEEKLY_CAP, "Weekly cap exceeded");
        
        // Transfer USDC to treasury
        USDC.transferFrom(msg.sender, address(treasury), usdcAmount);
        
        // Create bond
        userBonds[msg.sender].push(Bond({
            amount: agnAmount,
            vestingStart: block.timestamp,
            claimed: 0
        }));
        
        weeklyIssued += agnAmount;
        
        // Trigger treasury to buy ETH and execute buybacks
        treasury.processInflow(usdcAmount);
    }
    
    function claim(uint256 bondId) external {
        Bond storage bond = userBonds[msg.sender][bondId];
        require(bond.amount > 0, "Invalid bond");
        
        uint256 elapsed = block.timestamp - bond.vestingStart;
        uint256 vestingPeriod = VESTING_DAYS * 1 days;
        
        uint256 claimable;
        if (elapsed >= vestingPeriod) {
            claimable = bond.amount - bond.claimed;
        } else {
            claimable = (bond.amount * elapsed / vestingPeriod) - bond.claimed;
        }
        
        require(claimable > 0, "Nothing to claim");
        
        bond.claimed += claimable;
        AGN.transfer(msg.sender, claimable);
    }
}
```

### 3.2 StakingVault.sol
```solidity
contract StakingVault is ERC4626 {
    IERC20 public immutable USDC;
    IERC20 public immutable WETH;
    IERC20 public immutable AGN;
    IAaveAdapter public immutable aaveAdapter;
    ILidoAdapter public immutable lidoAdapter;
    ITreasury public immutable treasury;
    
    uint256 public constant FEE_BPS = 500; // 5%
    uint256 public constant BOOST_BPS = 500; // +5% for AGN lockers
    
    mapping(address => uint256) public agnLocked;
    mapping(address => uint256) public lockExpiry;
    
    function deposit(uint256 assets, address receiver, address asset) external {
        require(asset == address(USDC) || asset == address(WETH), "Invalid asset");
        
        // Calculate shares
        uint256 shares = previewDeposit(assets, asset);
        
        // Transfer assets
        IERC20(asset).transferFrom(msg.sender, address(this), assets);
        
        // Deploy to yield strategies
        if (asset == address(USDC)) {
            aaveAdapter.deposit(assets);
        } else {
            lidoAdapter.stake{value: assets}();
        }
        
        // Mint shares
        _mint(receiver, shares);
    }
    
    function harvest() external {
        // Harvest yields from adapters
        uint256 usdcYield = aaveAdapter.harvest();
        uint256 ethYield = lidoAdapter.harvest();
        
        // Calculate fees
        uint256 usdcFee = (usdcYield * FEE_BPS) / 10000;
        uint256 ethFee = (ethYield * FEE_BPS) / 10000;
        
        // Send fees to treasury for buybacks
        if (usdcFee > 0) {
            USDC.transfer(address(treasury), usdcFee);
            treasury.processInflow(usdcFee);
        }
        
        if (ethFee > 0) {
            WETH.transfer(address(treasury), ethFee);
            treasury.processETHInflow(ethFee);
        }
        
        // Calculate AGN boosts from fee portion
        uint256 boostBudget = ((usdcFee + ethFee) * 2000) / 10000; // 20% of fees
        _distributeBoosts(boostBudget);
    }
    
    function lockAGN(uint256 amount, uint256 lockDuration) external {
        require(lockDuration >= 30 days && lockDuration <= 365 days, "Invalid duration");
        
        AGN.transferFrom(msg.sender, address(this), amount);
        agnLocked[msg.sender] += amount;
        lockExpiry[msg.sender] = block.timestamp + lockDuration;
    }
    
    function getBoostMultiplier(address user) public view returns (uint256) {
        if (agnLocked[user] > 0 && block.timestamp < lockExpiry[user]) {
            return 10000 + BOOST_BPS; // +5%
        }
        return 10000; // No boost
    }
}
```

### 3.3 Treasury.sol Updates
```solidity
contract Treasury {
    // Add auto-buyback functionality
    function processInflow(uint256 amount) external {
        // Convert to ETH
        uint256 ethAmount = _swapUSDCToETH(amount);
        
        // 80% for buybacks, 20% hold as ETH
        uint256 buybackAmount = (ethAmount * 8000) / 10000;
        uint256 holdAmount = ethAmount - buybackAmount;
        
        // Execute buyback
        if (buybackAmount > 0) {
            buyback.executeBuyback(buybackAmount);
        }
        
        // Hold ETH (stake via Lido)
        if (holdAmount > 0) {
            lidoAdapter.stake{value: holdAmount}();
        }
        
        // Update TPT and emit events
        _updateTPT();
    }
    
    function calculateTPT() public view returns (uint256) {
        uint256 totalETH = address(this).balance + lidoAdapter.getBalance();
        uint256 circulatingSupply = AGN.totalSupply() - AGN.balanceOf(address(this));
        return (totalETH * 1e18) / circulatingSupply;
    }
}
```

---

## 4. Safety Parameters

### 4.1 Bond Safety Gates
- **Runway Check**: ≥6 months operational expenses
- **Coverage Ratio**: ≥1.2× treasury value vs. liabilities  
- **Weekly Cap**: 100K AGN maximum issuance
- **Pool Depth**: ≥$50K liquidity before enabling

### 4.2 Buyback Safety Gates
- **Volume Limit**: ≤10% of 30-day trading volume
- **TWAP Period**: 3-7 days based on size
- **Slippage Protection**: ≤2% maximum slippage
- **Burn Throttle**: 50% burn if runway/CR low, else 80%

### 4.3 Staking Safety
- **Single Venues**: Aave for USDC, Lido for ETH (no rebalancing)
- **Fee Caps**: 5% maximum on yields
- **Boost Budget**: ≤20% of fees for AGN boosts
- **Lock Minimums**: 30-365 days for AGN boosts

---

## 5. Frontend Integration

### 5.1 Bond Interface
- Simple USDC input with AGN preview
- Discount calculation display
- Vesting timeline and claim interface
- Safety gate status indicators

### 5.2 Staking Interface  
- USDC/ETH deposit options
- Yield projections with/without AGN boosts
- AGN locking interface for boosts
- Harvest and fee distribution tracking

### 5.3 Treasury Dashboard
- Real-time TPT metric
- ETH treasury growth chart
- Buyback execution history
- Safety gate status monitoring

---

## 6. Testing Requirements

### 6.1 Unit Tests
- Bond discount calculations and vesting
- Staking vault fee collection and boosts
- Safety gate enforcement edge cases
- Buyback execution with various scenarios

### 6.2 Integration Tests
- Full bond → ETH → buyback flow
- Staking fee → buyback execution
- Safety gate triggers and recovery
- Multi-user scenarios with caps

### 6.3 Invariant Tests
- Treasury value never decreases unexpectedly
- Total AGN supply only decreases (burns)
- Safety gates always enforced
- Fee calculations always accurate

---

## 7. Deployment Checklist

### Pre-Deploy
- [ ] All contracts tested (100% coverage)
- [ ] Chainlink price feed configured
- [ ] Safety parameters set conservatively
- [ ] Multisig controls configured

### Deploy Day
- [ ] Deploy in correct order with dependencies
- [ ] Initialize with safe parameters
- [ ] Seed initial AGN/USDC liquidity pool
- [ ] Test all functions with small amounts

### Post-Deploy
- [ ] Monitor first bond issuance
- [ ] Verify buyback execution
- [ ] Check TPT calculations
- [ ] Confirm safety gates working

---

## 8. Success Metrics

**Week 1:**
- [ ] Bonds issuing correctly with safety gates
- [ ] Staking vault attracting USDC/ETH deposits
- [ ] Automatic buybacks executing
- [ ] TPT published weekly

**Month 1:**
- [ ] >$1M total TVL across bonds and staking
- [ ] Consistent 80% burn rate
- [ ] ETH treasury growing steadily
- [ ] No failed transactions or safety violations

---

This ultra-simple implementation delivers maximum AGN value accrual through aggressive burns while maintaining operational safety and user-friendly interfaces.