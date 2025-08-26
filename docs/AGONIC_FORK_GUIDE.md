# Agonic Fork Guide - Ultra-Simple Treasury Protocol

**For teams wanting to fork Agonic's ultra-simple treasury accumulation and token deflation model**

---

## **What You're Forking**

Agonic is an **ultra-simple treasury protocol** with three core mechanisms:
1. **USDC Bonds** — Users deposit USDC for 10% discounted tokens (7-day vest)
2. **Staking Vault** — USDC/ETH staking with competitive yields and token boosts  
3. **Auto Buybacks** — 80% of inflows burn tokens, 20% to treasury operations

**Key Benefits**: Pure ETH treasury accumulation, aggressive token deflation, minimal complexity, "set it and forget it" operation.

---

## **Core Architecture (6 Contracts)**

### **1. SimpleBond.sol**
- **Purpose**: USDC-only bonds with fixed 10% discount
- **Features**: 7-day linear vesting, weekly caps, safety gates
- **Proceeds**: 100% to treasury for ETH accumulation

### **2. StakingVault.sol** 
- **Purpose**: ERC-4626 vault for USDC/ETH staking
- **Features**: 5% fees, token boosts for lockers, competitive yields
- **Integrations**: Aave (USDC), Lido (ETH)

### **3. Treasury.sol**
- **Purpose**: ETH accumulation and auto-buyback execution
- **Features**: Chainlink pricing, safety gates, TPT calculation
- **Flow**: Inflows → ETH buys → 80% buyback/burn, 20% hold

### **4. Buyback.sol**
- **Purpose**: TWAP token buybacks with burn/treasury split
- **Features**: 3-day TWAP, slippage protection, volume limits
- **Split**: 80% burn, 20% treasury operations

### **5. Gov.sol**
- **Purpose**: Token holder governance
- **Features**: Time-weighted voting, parameter updates
- **Scope**: Safety parameters, fees, contract upgrades

### **6. AttestationEmitter.sol**
- **Purpose**: Transparency events for all operations
- **Features**: Buyback logs, treasury updates, safety gate status
- **Use**: Frontend data, analytics, monitoring

---

## **Minimal Adapters (2 Contracts)**

### **AaveAdapter.sol**
- Fixed USDC lending to Aave v3
- No dynamic rebalancing or venue switching
- Simple deposit/withdraw/harvest functions

### **LidoAdapter.sol** 
- Direct ETH staking to Lido
- Automatic reward compounding
- Liquid staking token management

---

## **Fork Customization Options**

### **Asset Changes**
```solidity
// Change bond asset from USDC to your preferred stable
IERC20 public immutable BOND_ASSET = IERC20(YOUR_STABLE);

// Change treasury asset from ETH to your preferred reserve
IERC20 public immutable TREASURY_ASSET = IERC20(YOUR_ASSET);

// Update staking vault supported assets
address[] public supportedAssets = [YOUR_STABLE, YOUR_ASSET];
```

### **Parameter Tuning**
```solidity
// Bond parameters
uint256 public constant DISCOUNT_BPS = 1000;    // 10% discount
uint256 public constant VESTING_DAYS = 7;       // 7-day vest
uint256 public constant WEEKLY_CAP = 100000e18; // 100K tokens

// Buyback split
uint256 public constant BURN_BPS = 8000;        // 80% burn
uint256 public constant TREASURY_BPS = 2000;    // 20% treasury

// Safety gates
uint256 public constant MIN_RUNWAY_MONTHS = 6;  // 6 month runway
uint256 public constant MIN_COVERAGE_RATIO = 1.2e18; // 1.2x coverage
```

### **Yield Strategy Changes**
```solidity
// Replace Aave with your preferred lending protocol
contract YourAdapter {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external returns (uint256);
}

// Replace Lido with your preferred staking provider
contract YourStakingAdapter {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function getRewards() external returns (uint256);
}
```

---

## **Deployment Guide**

### **Step 1: Contract Deployment**
```bash
# Deploy core contracts in order
forge script script/DeployCore.s.sol --broadcast --verify

# Deploy adapters
forge script script/DeployAdapters.s.sol --broadcast --verify

# Initialize with parameters
forge script script/Initialize.s.sol --broadcast
```

### **Step 2: Parameter Configuration**
```solidity
// Set initial parameters
treasury.setMinRunway(6 * 30 days);
treasury.setMinCoverageRatio(1.2e18);
treasury.setChainlinkFeed(ETH_USD_FEED);

// Configure bond limits
simpleBond.setWeeklyCap(100000e18);
simpleBond.setDiscount(1000); // 10%

// Set vault fees
stakingVault.setFee(500); // 5%
stakingVault.setBoostRate(500); // +5%
```

### **Step 3: Initial Liquidity**
```solidity
// Seed initial token liquidity pool
// Recommended: $50K minimum depth
router.addLiquidity(
    TOKEN_ADDRESS,
    USDC_ADDRESS,
    tokenAmount,
    usdcAmount,
    deadline
);
```

### **Step 4: Frontend Deployment**
```bash
# Update contract addresses
cp deployments/mainnet.json frontend/contracts/

# Deploy frontend
npm run build
vercel deploy --prod
```

---

## **Customization Examples**

### **Example 1: BTC Treasury Protocol**
```solidity
// Change treasury asset to WBTC
IERC20 public immutable TREASURY_ASSET = IERC20(WBTC);

// Update pricing oracle
AggregatorV3Interface public btcUsdFeed = AggregatorV3Interface(BTC_USD_FEED);

// Modify treasury accumulation logic
function processInflow(uint256 amount) external {
    uint256 btcAmount = _swapUSDCToBTC(amount);
    // Rest remains the same
}
```

### **Example 2: Multi-Chain Deployment**
```solidity
// Polygon deployment with MATIC treasury
IERC20 public immutable TREASURY_ASSET = IERC20(WMATIC);

// Use Polygon-specific integrations
IAavePool public aavePool = IAavePool(POLYGON_AAVE_POOL);
IQuickSwap public dex = IQuickSwap(QUICKSWAP_ROUTER);
```

### **Example 3: DAO Treasury Manager**
```solidity
// Larger caps for institutional use
uint256 public constant WEEKLY_CAP = 1000000e18; // 1M tokens
uint256 public constant MIN_DEPOSIT = 10000e6;   // $10K minimum

// Different fee structure
uint256 public constant MANAGEMENT_FEE = 200;    // 2% annual
uint256 public constant PERFORMANCE_FEE = 1000;  // 10% on profits
```

---

## **Testing Your Fork**

### **Unit Tests**
```bash
# Test core functionality
forge test --match-contract SimpleBondTest
forge test --match-contract StakingVaultTest
forge test --match-contract TreasuryTest

# Test edge cases
forge test --match-test testSafetyGates
forge test --match-test testBuybackExecution
```

### **Integration Tests**
```bash
# Test full user flows
forge test --match-test testBondToBuybackFlow
forge test --match-test testStakingToFeesFlow
forge test --match-test testEmergencyScenarios
```

### **Fork Testing**
```bash
# Test against live protocols
forge test --fork-url $MAINNET_RPC --match-test testAaveIntegration
forge test --fork-url $MAINNET_RPC --match-test testLidoIntegration
```

---

## **Common Customizations**

### **Different Discount Mechanisms**
```solidity
// Dynamic discount based on treasury health
function getCurrentDiscount() public view returns (uint256) {
    uint256 cr = getCoverageRatio();
    if (cr > 2e18) return 500;      // 5% if healthy
    if (cr > 1.5e18) return 1000;   // 10% if normal  
    return 1500;                    // 15% if stressed
}
```

### **Alternative Vesting Schedules**
```solidity
// Cliff vesting instead of linear
function getClaimableAmount(uint256 bondId) public view returns (uint256) {
    Bond storage bond = userBonds[msg.sender][bondId];
    
    if (block.timestamp < bond.vestingStart + CLIFF_PERIOD) {
        return 0;
    }
    return bond.amount - bond.claimed;
}
```

### **Multi-Asset Bonds**
```solidity
// Support multiple bond assets
mapping(address => bool) public supportedBondAssets;
mapping(address => uint256) public assetDiscounts;

function deposit(address asset, uint256 amount) external {
    require(supportedBondAssets[asset], "Asset not supported");
    uint256 discount = assetDiscounts[asset];
    // Rest of bond logic...
}
```

---

## **Security Considerations**

### **Key Risks**
1. **Oracle Manipulation**: Use Chainlink with staleness checks
2. **Flash Loan Attacks**: Implement proper access controls
3. **Slippage Attacks**: Use TWAP and volume limits
4. **Governance Attacks**: Use timelocks and multisig

### **Recommended Protections**
```solidity
// Oracle staleness check
require(block.timestamp - updatedAt <= 3600, "Price too stale");

// Volume limits
require(amount <= getDailyVolumeLimit(), "Exceeds volume limit");

// Slippage protection  
require(amountOut >= minAmountOut, "Slippage too high");

// Access controls
modifier onlyAuthorized() {
    require(authorized[msg.sender], "Not authorized");
    _;
}
```

---

## **License & Attribution**

### **MIT License**
This codebase is MIT licensed - fork freely with attribution.

### **Required Attribution**
```solidity
// SPDX-License-Identifier: MIT
// Based on Agonic Protocol by [Your Team]
// Original: https://github.com/yourorg/agonic
```

### **Optional Recognition**
- Link to original Agonic protocol in documentation
- Credit in UI footer or about page
- Social media mention when launching

---

## **Support & Community**

### **Documentation**
- Full docs at `docs.agonic.xyz`
- Contract specifications in `/docs`
- Frontend examples in `/examples`

### **Community**
- Discord: [Your Discord]
- Twitter: [Your Twitter]  
- GitHub Discussions for technical questions

### **Professional Services**
- Custom deployment assistance
- Security review services
- Integration consulting

---

**Fork Agonic: Ultra-simple treasury protocol for any token and any treasury asset.**