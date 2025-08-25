# 🏦 **Agonic - Stable Yield Vault with ETH Treasury**

*Built from [StableSwap](https://github.com/DLhugly/StableSwap) foundation*

## **What is Agonic?**
A conservative yield vault that accumulates ETH treasury reserves (MicroStrategy-style) and performs disciplined AGN buybacks. Built on Base L2 infrastructure with professional-grade smart contracts.

## **Key Features**
1. **Multi-Stablecoin ERC-4626 Vault** - Conservative yield across USDC, USD1, EURC with automated protocol rebalancing (Aave, WLF, Uniswap V3, Aerodrome)
2. **ETH Treasury Accumulation** - Weekly DCA purchases funded by protocol fees + **automated FX arbitrage** + **ETH staking rewards**
3. **AGN Buyback Mechanism** - 40% of net yield → programmatic buybacks (gated by safety controls)
4. **Agonic Treasury Notes (ATN)** - Fixed-APR multi-stablecoin bonds to accelerate ETH accumulation
5. **Personalized Yield Simulator** - Interactive frontend tools for deposit modeling and "what-if" scenarios
6. **Built on StableSwap** - Proven multi-venue routing and Base L2 optimization

## **Repository Structure**

```
agonic/
├── README.md                    # This file
├── AGONIC_*.md                  # Planning documents and roadmaps
├── package.json                 # Monorepo scripts and workspace config
├── contracts/                   # 🔥 Smart contracts (Foundry)
│   ├── src/                    # Agonic v1 contracts
│   │   ├── StableVault4626.sol # Multi-stablecoin ERC-4626 vault
│   │   ├── Treasury.sol        # ETH accumulation + DCA + FX arbitrage
│   │   ├── TreasuryManager.sol # Multi-protocol rebalancing
│   │   ├── BondManager.sol     # ATN bond issuance
│   │   ├── ATNTranche.sol      # Individual bond tranches
│   │   ├── Buyback.sol         # Weekly TWAP buybacks
│   │   ├── Gov.sol             # Dual governance (AGN + LP stakers)
│   │   └── adapters/           # Protocol integrations
│   ├── script/                 # Deployment scripts
│   ├── test/                   # Contract tests
│   └── foundry.toml            # Foundry configuration
├── frontend/                    # 🔥 Next.js dapp
│   ├── app/                    # Next.js 13+ app directory
│   │   ├── page.tsx            # ETH Treasury Fortress dashboard
│   │   └── api/                # Backend API routes
│   ├── components/             # React components
│   │   ├── VaultCard.tsx       # Multi-stablecoin vault interface
│   │   ├── TreasuryChart.tsx   # ETH accumulation visualization
│   │   └── scaffold-eth/       # Scaffold-ETH components
│   ├── lib/                    # Shared utilities (from StableSwap)
│   │   ├── venues/             # DEX integrations
│   │   ├── tokens.ts           # Token metadata
│   │   └── math.ts             # BPS calculations
│   └── package.json            # Frontend dependencies
├── docs/                       # Documentation
│   └── UI_FRONTEND.md          # Frontend design specification
└── legacy/                     # Reference code from StableSwap fork
    ├── apps/stable-swap/       # Original StableSwap frontend
    ├── contracts/              # Original RouterExecutor.sol
    └── agonic-dapp/            # Unused Scaffold-ETH clone
```

## **Quick Start**

1. **Setup Everything**:
   ```bash
   npm run setup
   ```

2. **Start Development**:
   ```bash
   npm run dev
   ```

3. **Test Contracts**:
   ```bash
   npm run test:contracts
   ```

4. **Deploy to Base Sepolia**:
   ```bash
   npm run deploy:base-sepolia
   ```

### **Manual Setup (if needed)**
```bash
# Install frontend dependencies (with React 19 compatibility)
npm run setup:frontend

# Build contracts
npm run build:contracts
```

## **Implementation Status**

✅ **Complete Agonic v1 Implementation**
- **Smart Contracts**: Multi-stablecoin vault, ETH treasury, ATN bonds, buyback mechanism, dual governance
- **Frontend**: ETH Treasury Fortress dashboard with yield simulator and treasury visualization
- **Architecture**: Clean monorepo structure with Foundry + Next.js
- **Ready for**: Base L2 testnet deployment and conservative launch

## **Core Features (MVP)**

### **1. Multi-Venue Swap Routing**
1. **Uniswap v3 Integration**: QuoterV2 for quotes + Universal Router for execution
2. **Aerodrome Integration**: Solidly-style router with stable/volatile pool support
3. **Best Route Selection**: Compares venues and selects optimal execution path
4. **Fee Structure**: 5 bps fee collected by RouterExecutor contract

### **2. FX Dislocation Detection**
1. **Implied FX Calculation**: Derives EUR/USD rate from EURC/USDC pool quotes
2. **Oracle Integration**: Chainlink + Pyth EUR/USD median for reference rate
3. **Arbitrage Opportunities**: Identifies profitable dislocations after fees/slippage

### **3. Smart Contract Architecture**
1. **RouterExecutor.sol**: Allowlisted contract for secure swap execution
2. **Fee Collection**: Takes percentage fee on successful swaps
3. **MinOut Protection**: Enforces slippage protection and reverts on bad trades
4. **Multi-Router Support**: Works with both Uniswap Universal Router and Aerodrome

### **4. Base L2 Optimized**
1. **Low Gas Costs**: Optimized for Base network's sub-cent transaction fees
2. **Environment Configuration**: Supports multiple deployment environments
3. **Token Support**: USDC, EURC, USD1 with configurable addresses/decimals

## **Technical Stack**
1. **Frontend**: Next.js 15 + React 19 + Tailwind CSS 4
2. **Blockchain**: viem + wagmi for Base L2 interactions
3. **Smart Contracts**: Solidity ^0.8.20 with Foundry (planned)
4. **APIs**: Next.js API routes for server-side logic
5. **Architecture**: Monorepo ready for Taska expansion

## **API Endpoints**

### **POST /api/quote/route**
Returns best swap route between Uniswap v3 and Aerodrome
```json
{
  "venue": "univ3",
  "router": "0x...",
  "calldata": "0x...",
  "amountOut": "1000000",
  "minOut": "995000",
  "slipBps": 30,
  "netBps": 15
}
```

### **POST /api/fx/implied**
Calculates implied EUR/USD rate from EURC/USDC pools
```json
{
  "implied": 1.0845,
  "oracle": 1.0820,
  "deltaBps": 23,
  "venue": "univ3",
  "profitable": true
}
```



## **Development Status**
1. ✅ **Core swap routing** implemented
2. ✅ **Multi-venue quote aggregation** working  
3. ✅ **FX dislocation detection** functional
4. ✅ **RouterExecutor contract** deployed and tested
5. ✅ **Base L2 integration** complete

## **Getting Started**

### **Installation**
```bash
git clone https://github.com/DLhugly/YLD9.git agonic
cd agonic/apps/stable-swap
npm install
```

### **Environment Setup**
Create `.env.local` with required variables:
```bash
# Base L2 RPC endpoint
RPC_URL_BASE="https://your-base-rpc"

# Contract addresses (Base network)
USDC_ADDR="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
EURC_ADDR="0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42" 
UNIV3_UNIVERSAL_ROUTER="0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD"
UNIV3_QUOTER_V2="0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a"
AERODROME_ROUTER="0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43"

# Oracle feeds
CHAINLINK_EURUSD_FEED="0x02F5E9e9dcc66ba6392f6904D5Fcf8625d9B65C4"
PYTH_ENDPOINT="0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a"

# Trading parameters
ROUTER_FEE_BPS="5"
DEFAULT_SLIPPAGE_BPS="30" 
SAFETY_BUFFER_BPS="10"
```

### **Run Development Server**
```bash
npm run dev
```

Visit `http://localhost:3000` to access the current swap interface (will be adapted to vault UI).

## **Project Documentation**

### **Implementation Plans**
- **[AGONIC_PHASE1_ROADMAP.md](./AGONIC_PHASE1_ROADMAP.md)** - Day-one product: vault, treasury, bonds (4-8 weeks)  
- **[AGONIC_PHASE2_APPCHAIN.md](./AGONIC_PHASE2_APPCHAIN.md)** - L3 chain evolution with AGN gas token (6-12 months)
- **[AGONIC_EXTENDED_ROADMAP.md](./AGONIC_EXTENDED_ROADMAP.md)** - Complete technical specification
- **[AGONIC_FORK_GUIDE.md](./AGONIC_FORK_GUIDE.md)** - Development setup and architecture guide

### **Key Parameters (Phase 1)**
1. **Vault Asset:** USDC (Base L2)
2. **Fee on Yield:** 12% (never on principal)  
3. **Weekly DCA Cap:** $5,000 USDC → ETH
4. **Buyback Allocation:** 40% of net yield (gated by safety controls)
5. **Safety Gates:** 6-month runway + 1.2× coverage ratio

## **License**
MIT License - see LICENSE file for details

## **Network**
**Base L2** (Chain ID: 8453) - Optimized for sub-cent transaction costs

---

*Stable yield with disciplined ETH accumulation and programmatic buybacks*



