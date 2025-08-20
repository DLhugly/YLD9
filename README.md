apps/stable-swap/
├─ .env.local               # RPC, oracle addrs, router addrs, fee bps
├─ next.config.js
├─ package.json
├─ src/
│  ├─ app/
│  │  ├─ page.tsx          # Dashboard (Swap + Dislocation)
│  │  ├─ api/
│  │  │  ├─ quote/route.ts # Get best route (uni v3 vs aerodrome)
│  │  │  ├─ fx/implied.ts  # Implied FX from pool quote
│  │  │  └─ fx/trigger.ts  # (Optional) cron/trigger endpoint
│  ├─ components/
│  │  ├─ SwapCard.tsx
│  │  ├─ DislocationTile.tsx
│  │  └─ SettingsDrawer.tsx
│  ├─ lib/
│  │  ├─ tokens.ts         # hardcoded token meta + addresses
│  │  ├─ venues/
│  │  │  ├─ univ3.ts       # quote+build calldata via Quoter/UR
│  │  │  └─ aerodrome.ts   # quote+build calldata via router
│  │  ├─ oracles.ts        # chainlink+pyth readers
│  │  ├─ slippage.ts       # slip model + minOut
│  │  └─ math.ts           # bps, gas $, rounding, decimal helpers
│  └─ state/
│     └─ telemetry.ts      # send fills/fails to console or tiny db
contracts/
├─ src/RouterExecutor.sol   # minimal executor
├─ foundry.toml
└─ test/RouterExecutor.t.sol



