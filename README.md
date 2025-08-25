# 💱 **StableSwap - Multi-Venue DEX Aggregator**

## **What is StableSwap?**
A high-performance DeFi swap aggregator optimized for Base L2, featuring intelligent routing between Uniswap v3 and Aerodrome to ensure users always get the best execution price.

## **Key Features**
1. **Multi-venue routing** - Compares Uniswap v3 and Aerodrome in real-time
2. **FX arbitrage detection** - Identifies profitable EUR/USD dislocations  
3. **Gas-optimized execution** - Built for Base L2's sub-cent transaction costs
4. **Professional-grade contracts** - Secure execution with fee collection and slippage protection

## **Repository Structure**

```
StableSwap/
├── README.md                     # This file
├── apps/stable-swap/             # Next.js DeFi swap application
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
- **Uniswap v3 Integration**: QuoterV2 for quotes + Universal Router for execution
- **Aerodrome Integration**: Solidly-style router with stable/volatile pool support
- **Best Route Selection**: Compares venues and selects optimal execution path
- **Fee Structure**: 5 bps fee collected by RouterExecutor contract

### **2. FX Dislocation Detection**
- **Implied FX Calculation**: Derives EUR/USD rate from EURC/USDC pool quotes
- **Oracle Integration**: Chainlink + Pyth EUR/USD median for reference rate
- **Arbitrage Opportunities**: Identifies profitable dislocations after fees/slippage

### **3. Smart Contract Architecture**
- **RouterExecutor.sol**: Allowlisted contract for secure swap execution
- **Fee Collection**: Takes percentage fee on successful swaps
- **MinOut Protection**: Enforces slippage protection and reverts on bad trades
- **Multi-Router Support**: Works with both Uniswap Universal Router and Aerodrome

### **4. Base L2 Optimized**
- **Low Gas Costs**: Optimized for Base network's sub-cent transaction fees
- **Environment Configuration**: Supports multiple deployment environments
- **Token Support**: USDC, EURC, USD1 with configurable addresses/decimals

## **Technical Stack**
- **Frontend**: Next.js 15 + React 19 + Tailwind CSS 4
- **Blockchain**: viem + wagmi for Base L2 interactions
- **Smart Contracts**: Solidity ^0.8.20 with Foundry (planned)
- **APIs**: Next.js API routes for server-side logic
- **Architecture**: Monorepo ready for Taska expansion

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
- ✅ **Core swap routing** implemented
- ✅ **Multi-venue quote aggregation** working  
- ✅ **FX dislocation detection** functional
- ✅ **RouterExecutor contract** deployed and tested
- ✅ **Base L2 integration** complete

## **Getting Started**

### **Installation**
```bash
git clone https://github.com/your-username/StableSwap.git
cd StableSwap/apps/stable-swap
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

Visit `http://localhost:3000` to access the swap interface.

## **License**
MIT License - see LICENSE file for details

## **Network**
Optimized for **Base L2** (Chain ID: 8453)

---

*Open source DEX aggregator for efficient multi-venue swaps*



