"use client";

import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { 
  TrendingUp, 
  TrendingDown,
  DollarSign, 
  Euro,
  RefreshCw,
  Zap,
  AlertTriangle,
  CheckCircle,
  Clock,
  ArrowRightLeft,
  Target
} from "lucide-react";
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar } from "recharts";

interface FXPair {
  from: string;
  to: string;
  currentRate: number;
  impliedRate: number;
  deviation: number;
  threshold: number;
  status: "opportunity" | "monitoring" | "executed";
  lastUpdate: Date;
  volume24h: number;
}

interface ArbitrageExecution {
  id: string;
  timestamp: Date;
  fromAsset: string;
  toAsset: string;
  amountIn: number;
  amountOut: number;
  profit: number;
  venue: string;
  txHash: string;
  status: "completed" | "pending" | "failed";
}

interface PriceHistory {
  timestamp: Date;
  usdc_usd1: number;
  usdc_eurc: number;
  usd1_eurc: number;
}

export default function FXArbitrageUI() {
  const [fxPairs, setFxPairs] = useState<FXPair[]>([]);
  const [arbitrageHistory, setArbitrageHistory] = useState<ArbitrageExecution[]>([]);
  const [priceHistory, setPriceHistory] = useState<PriceHistory[]>([]);
  const [totalStats, setTotalStats] = useState({
    totalProfit: 0,
    successfulArbitrages: 0,
    averageProfit: 0,
    bestOpportunity: 0
  });
  const [autoArbitrage, setAutoArbitrage] = useState(true);

  useEffect(() => {
    // Mock data - in production, fetch from Treasury contract and price oracles
    const mockFXPairs: FXPair[] = [
      {
        from: "USDC",
        to: "USD1",
        currentRate: 1.0015,
        impliedRate: 1.0000,
        deviation: 0.15,
        threshold: 0.10,
        status: "opportunity",
        lastUpdate: new Date(Date.now() - 5 * 60 * 1000),
        volume24h: 250000
      },
      {
        from: "USDC", 
        to: "EURC",
        currentRate: 0.9234,
        impliedRate: 0.9245,
        deviation: -0.12,
        threshold: 0.10,
        status: "opportunity",
        lastUpdate: new Date(Date.now() - 3 * 60 * 1000),
        volume24h: 180000
      },
      {
        from: "USD1",
        to: "EURC", 
        currentRate: 0.9221,
        impliedRate: 0.9245,
        deviation: -0.26,
        threshold: 0.10,
        status: "opportunity",
        lastUpdate: new Date(Date.now() - 2 * 60 * 1000),
        volume24h: 95000
      }
    ];

    const mockArbitrages: ArbitrageExecution[] = [
      {
        id: "arb-1",
        timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000),
        fromAsset: "USDC",
        toAsset: "USD1",
        amountIn: 10000,
        amountOut: 10015,
        profit: 15,
        venue: "Uniswap V3",
        txHash: "0x123...abc",
        status: "completed"
      },
      {
        id: "arb-2",
        timestamp: new Date(Date.now() - 4 * 60 * 60 * 1000),
        fromAsset: "USD1",
        toAsset: "EURC",
        amountIn: 15000,
        amountOut: 13845,
        profit: 32,
        venue: "Aerodrome",
        txHash: "0x456...def", 
        status: "completed"
      },
      {
        id: "arb-3",
        timestamp: new Date(Date.now() - 6 * 60 * 60 * 1000),
        fromAsset: "EURC",
        toAsset: "USDC",
        amountIn: 8000,
        amountOut: 8665,
        profit: 18,
        venue: "Uniswap V3",
        txHash: "0x789...ghi",
        status: "completed"
      },
      {
        id: "arb-4",
        timestamp: new Date(Date.now() - 8 * 60 * 60 * 1000),
        fromAsset: "USDC",
        toAsset: "EURC",
        amountIn: 12000,
        amountOut: 11085,
        profit: 24,
        venue: "Aerodrome",
        txHash: "0xabc...123",
        status: "completed"
      }
    ];

    const mockPriceHistory: PriceHistory[] = [
      { timestamp: new Date(Date.now() - 24 * 60 * 60 * 1000), usdc_usd1: 1.0008, usdc_eurc: 0.9245, usd1_eurc: 0.9237 },
      { timestamp: new Date(Date.now() - 20 * 60 * 60 * 1000), usdc_usd1: 1.0012, usdc_eurc: 0.9241, usd1_eurc: 0.9229 },
      { timestamp: new Date(Date.now() - 16 * 60 * 60 * 1000), usdc_usd1: 1.0005, usdc_eurc: 0.9248, usd1_eurc: 0.9243 },
      { timestamp: new Date(Date.now() - 12 * 60 * 60 * 1000), usdc_usd1: 1.0018, usdc_eurc: 0.9238, usd1_eurc: 0.9220 },
      { timestamp: new Date(Date.now() - 8 * 60 * 60 * 1000), usdc_usd1: 1.0003, usdc_eurc: 0.9252, usd1_eurc: 0.9249 },
      { timestamp: new Date(Date.now() - 4 * 60 * 60 * 1000), usdc_usd1: 1.0021, usdc_eurc: 0.9235, usd1_eurc: 0.9214 },
      { timestamp: new Date(), usdc_usd1: 1.0015, usdc_eurc: 0.9234, usd1_eurc: 0.9221 }
    ];

    setFxPairs(mockFXPairs);
    setArbitrageHistory(mockArbitrages);
    setPriceHistory(mockPriceHistory);

    // Calculate total stats
    const totalProfit = mockArbitrages.filter(a => a.status === "completed").reduce((sum, a) => sum + a.profit, 0);
    const successfulArbitrages = mockArbitrages.filter(a => a.status === "completed").length;
    const averageProfit = totalProfit / successfulArbitrages;
    const bestOpportunity = Math.max(...mockFXPairs.map(p => Math.abs(p.deviation)));

    setTotalStats({
      totalProfit,
      successfulArbitrages,
      averageProfit,
      bestOpportunity
    });
  }, []);

  const formatCurrency = (amount: number, currency: string = "USD") => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency === "EURC" ? "EUR" : "USD",
      minimumFractionDigits: 2
    }).format(amount);
  };

  const formatPercent = (percent: number) => {
    return `${percent >= 0 ? '+' : ''}${percent.toFixed(3)}%`;
  };

  const formatRate = (rate: number) => {
    return rate.toFixed(6);
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getOpportunityColor = (deviation: number, threshold: number) => {
    const absDeviation = Math.abs(deviation);
    if (absDeviation >= threshold * 2) return "text-red-600 bg-red-50";
    if (absDeviation >= threshold) return "text-yellow-600 bg-yellow-50";
    return "text-green-600 bg-green-50";
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "opportunity": return <Target className="h-4 w-4" />;
      case "monitoring": return <Clock className="h-4 w-4" />;
      case "executed": return <CheckCircle className="h-4 w-4" />;
      default: return <AlertTriangle className="h-4 w-4" />;
    }
  };

  const handleExecuteArbitrage = async (pair: FXPair) => {
    // In production: call Treasury.executeFXArbitrage()
    console.log("Executing arbitrage for", pair.from, "->", pair.to);
    alert(`Executing FX arbitrage: ${pair.from} → ${pair.to}`);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">FX Arbitrage Dashboard</h2>
          <p className="text-muted-foreground">
            USDC/USD1/EURC price monitoring and automated arbitrage
          </p>
        </div>
        <div className="flex items-center space-x-3">
          <div className="flex items-center space-x-2">
            <div className={`w-2 h-2 rounded-full ${autoArbitrage ? 'bg-green-500' : 'bg-red-500'}`}></div>
            <span className="text-sm">Auto Arbitrage: {autoArbitrage ? 'ON' : 'OFF'}</span>
          </div>
          <Button variant="outline" size="sm">
            <RefreshCw className="h-4 w-4 mr-2" />
            Refresh Prices
          </Button>
        </div>
      </div>

      <Tabs defaultValue="opportunities" className="space-y-4">
        <TabsList>
          <TabsTrigger value="opportunities">Current Opportunities</TabsTrigger>
          <TabsTrigger value="monitoring">Price Monitoring</TabsTrigger>
          <TabsTrigger value="history">Execution History</TabsTrigger>
          <TabsTrigger value="settings">Arbitrage Settings</TabsTrigger>
        </TabsList>

        <TabsContent value="opportunities" className="space-y-4">
          {/* Key Stats */}
          <div className="grid gap-4 md:grid-cols-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total Profit</CardTitle>
                <DollarSign className="h-4 w-4 text-green-600" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-green-600">
                  {formatCurrency(totalStats.totalProfit)}
                </div>
                <p className="text-xs text-muted-foreground">
                  Last 24 hours
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Successful Arbitrages</CardTitle>
                <CheckCircle className="h-4 w-4 text-green-600" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{totalStats.successfulArbitrages}</div>
                <p className="text-xs text-muted-foreground">
                  Executions completed
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Average Profit</CardTitle>
                <TrendingUp className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {formatCurrency(totalStats.averageProfit)}
                </div>
                <p className="text-xs text-muted-foreground">
                  Per arbitrage
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Best Opportunity</CardTitle>
                <Target className="h-4 w-4 text-orange-500" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-orange-600">
                  {formatPercent(totalStats.bestOpportunity)}
                </div>
                <p className="text-xs text-muted-foreground">
                  Current deviation
                </p>
              </CardContent>
            </Card>
          </div>

          {/* Current Opportunities */}
          <div className="space-y-4">
            <h3 className="text-lg font-semibold">Active FX Pairs</h3>
            {fxPairs.map((pair, index) => (
              <Card key={index}>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="flex items-center gap-2">
                      <ArrowRightLeft className="h-5 w-5" />
                      {pair.from} → {pair.to}
                    </CardTitle>
                    <div className="flex items-center space-x-2">
                      <Badge className={getOpportunityColor(pair.deviation, pair.threshold)}>
                        {getStatusIcon(pair.status)}
                        {formatPercent(pair.deviation)}
                      </Badge>
                      {Math.abs(pair.deviation) >= pair.threshold && (
                        <Button 
                          size="sm" 
                          onClick={() => handleExecuteArbitrage(pair)}
                          disabled={!autoArbitrage}
                        >
                          <Zap className="h-4 w-4 mr-1" />
                          Execute
                        </Button>
                      )}
                    </div>
                  </div>
                  <CardDescription>
                    Threshold: ±{formatPercent(pair.threshold)} • 24h Volume: {formatCurrency(pair.volume24h)}
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                    <div>
                      <span className="text-muted-foreground">Current Rate:</span>
                      <div className="font-semibold">{formatRate(pair.currentRate)}</div>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Implied Rate:</span>
                      <div className="font-semibold">{formatRate(pair.impliedRate)}</div>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Deviation:</span>
                      <div className={`font-semibold ${pair.deviation >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                        {formatPercent(pair.deviation)}
                      </div>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Last Update:</span>
                      <div className="font-semibold">{formatDate(pair.lastUpdate)}</div>
                    </div>
                  </div>
                  <div className="mt-3">
                    <div className="flex justify-between text-xs text-muted-foreground mb-1">
                      <span>Threshold Progress</span>
                      <span>{Math.abs(pair.deviation).toFixed(3)}% / {pair.threshold.toFixed(2)}%</span>
                    </div>
                    <Progress 
                      value={Math.min((Math.abs(pair.deviation) / pair.threshold) * 100, 100)}
                      className="h-2"
                    />
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </TabsContent>

        <TabsContent value="monitoring" className="space-y-4">
          <h3 className="text-lg font-semibold">FX Rate Monitoring (24 Hours)</h3>
          <Card>
            <CardHeader>
              <CardTitle>Exchange Rate Trends</CardTitle>
              <CardDescription>Real-time price movements across stablecoin pairs</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="h-[400px]">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={priceHistory}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis 
                      dataKey="timestamp"
                      tickFormatter={(value) => new Date(value).toLocaleTimeString()}
                    />
                    <YAxis 
                      domain={['dataMin - 0.001', 'dataMax + 0.001']}
                      tickFormatter={(value) => value.toFixed(4)}
                    />
                    <Tooltip 
                      labelFormatter={(value) => new Date(value).toLocaleString()}
                      formatter={(value: number, name: string) => [
                        value.toFixed(6),
                        name.replace('_', '/').toUpperCase()
                      ]}
                    />
                    <Line 
                      type="monotone" 
                      dataKey="usdc_usd1" 
                      stroke="#3b82f6" 
                      strokeWidth={2}
                      dot={false}
                      name="USDC/USD1"
                    />
                    <Line 
                      type="monotone" 
                      dataKey="usdc_eurc" 
                      stroke="#10b981" 
                      strokeWidth={2}
                      dot={false}
                      name="USDC/EURC"
                    />
                    <Line 
                      type="monotone" 
                      dataKey="usd1_eurc" 
                      stroke="#f59e0b" 
                      strokeWidth={2}
                      dot={false}
                      name="USD1/EURC"
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="history" className="space-y-4">
          <h3 className="text-lg font-semibold">Recent Arbitrage Executions</h3>
          <Card>
            <CardContent className="p-0">
              <div className="divide-y">
                {arbitrageHistory.map((execution) => (
                  <div key={execution.id} className="p-4">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center space-x-2">
                        <Badge variant={execution.status === "completed" ? "default" : "secondary"}>
                          {execution.status}
                        </Badge>
                        <span className="font-medium">
                          {execution.fromAsset} → {execution.toAsset}
                        </span>
                        <span className="text-sm text-muted-foreground">
                          via {execution.venue}
                        </span>
                      </div>
                      <div className="text-sm text-muted-foreground">
                        {formatDate(execution.timestamp)}
                      </div>
                    </div>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                      <div>
                        <span className="text-muted-foreground">Amount In:</span>
                        <div className="font-semibold">
                          {formatCurrency(execution.amountIn, execution.fromAsset)}
                        </div>
                      </div>
                      <div>
                        <span className="text-muted-foreground">Amount Out:</span>
                        <div className="font-semibold">
                          {formatCurrency(execution.amountOut, execution.toAsset)}
                        </div>
                      </div>
                      <div>
                        <span className="text-muted-foreground">Profit:</span>
                        <div className="font-semibold text-green-600">
                          +{formatCurrency(execution.profit)}
                        </div>
                      </div>
                      <div>
                        <span className="text-muted-foreground">Tx Hash:</span>
                        <div className="font-mono text-xs">{execution.txHash}</div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="settings" className="space-y-4">
          <h3 className="text-lg font-semibold">Arbitrage Configuration</h3>
          <div className="grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>Automation Settings</CardTitle>
                <CardDescription>Configure automatic arbitrage execution</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="font-medium">Auto Arbitrage</div>
                    <div className="text-sm text-muted-foreground">
                      Automatically execute profitable arbitrages
                    </div>
                  </div>
                  <Button 
                    variant={autoArbitrage ? "default" : "outline"}
                    size="sm"
                    onClick={() => setAutoArbitrage(!autoArbitrage)}
                  >
                    {autoArbitrage ? "ON" : "OFF"}
                  </Button>
                </div>
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Execution Threshold:</span>
                    <span>0.10%</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span>Max Position Size:</span>
                    <span>$50,000</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span>Slippage Tolerance:</span>
                    <span>0.5%</span>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Risk Management</CardTitle>
                <CardDescription>Safety parameters and limits</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Daily Arbitrage Limit:</span>
                    <span>$100,000</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span>Today's Usage:</span>
                    <span className="text-green-600">$23,450 (23.5%)</span>
                  </div>
                  <Progress value={23.5} className="h-2" />
                </div>
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Minimum Profit Threshold:</span>
                    <span>$5.00</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span>Gas Price Limit:</span>
                    <span>50 gwei</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}
