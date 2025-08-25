# 🏦 **Agonic - Stable Yield Vault with ETH Treasury**

*Built from [StableSwap](https://github.com/DLhugly/StableSwap) foundation*

## **What is Agonic?**
A conservative yield vault that accumulates ETH treasury reserves (MicroStrategy-style) and performs disciplined AGN buybacks. Built on Base L2 infrastructure with professional-grade smart contracts.

## **Key Features**
1. **ERC-4626 USDC Vault** - Conservative yield farming with venue caps and safety buffers
2. **ETH Treasury Accumulation** - Weekly DCA purchases funded by protocol fees  
3. **AGN Buyback Mechanism** - 40% of net yield → programmatic buybacks (gated by safety controls)
4. **Agonic Treasury Notes (ATN)** - Fixed-APR USDC bonds to accelerate ETH accumulation
5. **Built on StableSwap** - Proven multi-venue routing and Base L2 optimization

## **Repository Structure**

```
Agonic/
├── README.md                     # Project overview
├── AGONIC_PHASE1_ROADMAP.md      # 4-8 week implementation plan
├── AGONIC_PHASE2_APPCHAIN.md     # App chain evolution strategy  
├── AGONIC_EXTENDED_ROADMAP.md    # Full technical specification
├── AGONIC_FORK_GUIDE.md          # Development setup guide
├── apps/stable-swap/             # Next.js foundation (will become vault UI)
│   ├── package.json             # Dependencies: React 19, Next.js 15, viem, wagmi
│   ├── src/
│   │   ├── app/
│   │   │   ├── page.tsx         # Main dashboard with SwapCard
│   │   │   ├── layout.tsx       # App layout and metadata
│   │   │   ├── globals.css      # Tailwind CSS styles
│   │   │   └── api/             # Server-side API routes
│   │   │       ├── quote/route.ts    # Best route selection (Uniswap v3 vs Aerodrome)
│   │   │       └── fx/
│   │   │           ├── implied/route.ts  # Implied EUR/USD from EURC/USDC pools
│   │   │           └── trigger/route.ts  # Placeholder for FX triggers
│   │   ├── components/
│   │   │   └── SwapCard.tsx     # Swap interface component
│   │   ├── lib/                 # Core business logic
│   │   │   ├── viem.ts         # Viem client for Base L2
│   │   │   ├── config.ts       # Environment-driven configuration
│   │   │   ├── tokens.ts       # Token metadata (USDC, EURC, USD1)
│   │   │   ├── math.ts         # BPS calculations and decimal helpers
│   │   │   ├── slippage.ts     # Slippage modeling and minOut calculation
│   │   │   └── venues/         # DEX integrations
│   │   │       ├── univ3.ts    # Uniswap v3 QuoterV2 + Universal Router
│   │   │       └── aerodrome.ts # Aerodrome Solidly-style router
│   │   └── state/
│   │       └── telemetry.ts    # Trade execution logging
└── contracts/
    └── src/
        └── RouterExecutor.sol   # Minimal swap executor with fee collection
```

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
- **[AGONIC_PHASE2_APPCHAIN.md](./AGONIC_PHASE2_APPCHAIN.md)** - App chain evolution with proof-of-task (6-12 months)
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



