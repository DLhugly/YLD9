"use client";

import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { 
  TrendingUp, 
  TrendingDown,
  Activity, 
  BarChart3, 
  PieChart as PieChartIcon,
  RefreshCw,
  Target,
  AlertCircle,
  CheckCircle
} from "lucide-react";
import { 
  LineChart, 
  Line, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer, 
  PieChart, 
  Pie, 
  Cell,
  BarChart,
  Bar
} from "recharts";

interface ProtocolStrategy {
  name: string;
  type: "lending" | "uniswap_v3" | "aerodrome";
  currentAPY: number;
  historicalAPY: number[];
  tvl: number;
  allocation: number;
  maxAllocation: number;
  status: "active" | "paused" | "rebalancing";
  riskLevel: "low" | "medium" | "high";
  lastRebalance: Date;
  yieldGenerated: number;
}

interface RebalanceEvent {
  id: string;
  timestamp: Date;
  fromProtocol: string;
  toProtocol: string;
  amount: number;
  reason: string;
  oldAPY: number;
  newAPY: number;
  status: "completed" | "pending" | "failed";
}

interface HistoricalPerformance {
  date: Date;
  aave: number;
  wlf: number;
  uniswap: number;
  aerodrome: number;
  weighted: number;
}

export default function StrategyPerformance() {
  const [protocols, setProtocols] = useState<ProtocolStrategy[]>([]);
  const [rebalanceHistory, setRebalanceHistory] = useState<RebalanceEvent[]>([]);
  const [performanceData, setPerformanceData] = useState<HistoricalPerformance[]>([]);
  const [totalStats, setTotalStats] = useState({
    totalTVL: 0,
    weightedAPY: 0,
    totalYieldGenerated: 0,
    bestPerformer: "",
    worstPerformer: ""
  });

  useEffect(() => {
    // Mock data - in production, fetch from TreasuryManager contract
    const mockProtocols: ProtocolStrategy[] = [
      {
        name: "Aave v3",
        type: "lending",
        currentAPY: 3.2,
        historicalAPY: [2.8, 3.0, 3.1, 3.2, 3.0, 2.9, 3.2],
        tvl: 180000,
        allocation: 60,
        maxAllocation: 60,
        status: "active",
        riskLevel: "low",
        lastRebalance: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000),
        yieldGenerated: 14400
      },
      {
        name: "World Liberty Financial",
        type: "lending", 
        currentAPY: 5.1,
        historicalAPY: [4.8, 5.0, 5.2, 5.1, 4.9, 5.3, 5.1],
        tvl: 120000,
        allocation: 40,
        maxAllocation: 40,
        status: "active",
        riskLevel: "medium",
        lastRebalance: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000),
        yieldGenerated: 12240
      },
      {
        name: "Uniswap V3",
        type: "uniswap_v3",
        currentAPY: 8.7,
        historicalAPY: [7.2, 8.1, 9.3, 8.7, 7.8, 8.5, 8.7],
        tvl: 90000,
        allocation: 30,
        maxAllocation: 30,
        status: "rebalancing",
        riskLevel: "high",
        lastRebalance: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
        yieldGenerated: 15660
      },
      {
        name: "Aerodrome",
        type: "aerodrome",
        currentAPY: 12.4,
        historicalAPY: [10.8, 11.5, 12.1, 12.4, 11.9, 12.8, 12.4],
        tvl: 90000,
        allocation: 30,
        maxAllocation: 30,
        status: "active",
        riskLevel: "high", 
        lastRebalance: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
        yieldGenerated: 22320
      }
    ];

    const mockRebalances: RebalanceEvent[] = [
      {
        id: "rebalance-1",
        timestamp: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
        fromProtocol: "Aave v3",
        toProtocol: "Uniswap V3", 
        amount: 15000,
        reason: "Higher yield opportunity detected",
        oldAPY: 3.2,
        newAPY: 8.7,
        status: "completed"
      },
      {
        id: "rebalance-2",
        timestamp: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000),
        fromProtocol: "WLF",
        toProtocol: "Aerodrome",
        amount: 25000,
        reason: "Risk-adjusted yield optimization",
        oldAPY: 5.1,
        newAPY: 12.4,
        status: "completed"
      },
      {
        id: "rebalance-3",
        timestamp: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000),
        fromProtocol: "Uniswap V3",
        toProtocol: "Aave v3",
        amount: 20000,
        reason: "Volatility reduction",
        oldAPY: 8.7,
        newAPY: 3.2,
        status: "completed"
      }
    ];

    const mockPerformance: HistoricalPerformance[] = [
      { date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000), aave: 2.8, wlf: 4.8, uniswap: 7.2, aerodrome: 10.8, weighted: 5.2 },
      { date: new Date(Date.now() - 25 * 24 * 60 * 60 * 1000), aave: 3.0, wlf: 5.0, uniswap: 8.1, aerodrome: 11.5, weighted: 5.8 },
      { date: new Date(Date.now() - 20 * 24 * 60 * 60 * 1000), aave: 3.1, wlf: 5.2, uniswap: 9.3, aerodrome: 12.1, weighted: 6.4 },
      { date: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000), aave: 3.2, wlf: 5.1, uniswap: 8.7, aerodrome: 12.4, weighted: 6.2 },
      { date: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000), aave: 3.0, wlf: 4.9, uniswap: 7.8, aerodrome: 11.9, weighted: 5.9 },
      { date: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000), aave: 2.9, wlf: 5.3, uniswap: 8.5, aerodrome: 12.8, weighted: 6.3 },
      { date: new Date(), aave: 3.2, wlf: 5.1, uniswap: 8.7, aerodrome: 12.4, weighted: 6.1 }
    ];

    setProtocols(mockProtocols);
    setRebalanceHistory(mockRebalances);
    setPerformanceData(mockPerformance);

    // Calculate total stats
    const totalTVL = mockProtocols.reduce((sum, p) => sum + p.tvl, 0);
    const weightedAPY = mockProtocols.reduce((sum, p) => sum + (p.currentAPY * p.tvl), 0) / totalTVL;
    const totalYieldGenerated = mockProtocols.reduce((sum, p) => sum + p.yieldGenerated, 0);
    const bestPerformer = mockProtocols.reduce((best, p) => p.currentAPY > best.currentAPY ? p : best).name;
    const worstPerformer = mockProtocols.reduce((worst, p) => p.currentAPY < worst.currentAPY ? p : worst).name;

    setTotalStats({
      totalTVL,
      weightedAPY,
      totalYieldGenerated,
      bestPerformer,
      worstPerformer
    });
  }, []);

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount);
  };

  const formatPercent = (percent: number) => {
    return `${percent.toFixed(2)}%`;
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case "active": return "bg-green-50 text-green-700";
      case "paused": return "bg-yellow-50 text-yellow-700";
      case "rebalancing": return "bg-blue-50 text-blue-700";
      default: return "bg-gray-50 text-gray-700";
    }
  };

  const getRiskColor = (risk: string) => {
    switch (risk) {
      case "low": return "text-green-600";
      case "medium": return "text-yellow-600";
      case "high": return "text-red-600";
      default: return "text-gray-600";
    }
  };

  const allocationData = protocols.map(p => ({
    name: p.name,
    value: p.tvl,
    color: p.name === "Aave v3" ? "#3b82f6" : 
           p.name === "World Liberty Financial" ? "#10b981" :
           p.name === "Uniswap V3" ? "#f59e0b" : "#ef4444"
  }));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Strategy Performance</h2>
          <p className="text-muted-foreground">
            Real-time APY comparison and multi-protocol allocation
          </p>
        </div>
        <Button variant="outline" size="sm">
          <RefreshCw className="h-4 w-4 mr-2" />
          Refresh Data
        </Button>
      </div>

      <Tabs defaultValue="overview" className="space-y-4">
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="protocols">Protocol Details</TabsTrigger>
          <TabsTrigger value="performance">Historical Performance</TabsTrigger>
          <TabsTrigger value="rebalancing">Rebalancing Events</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-4">
          {/* Key Metrics */}
          <div className="grid gap-4 md:grid-cols-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total TVL</CardTitle>
                <Target className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{formatCurrency(totalStats.totalTVL)}</div>
                <p className="text-xs text-muted-foreground">
                  Across {protocols.length} protocols
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Weighted APY</CardTitle>
                <TrendingUp className="h-4 w-4 text-green-600" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-green-600">
                  {formatPercent(totalStats.weightedAPY)}
                </div>
                <p className="text-xs text-muted-foreground">
                  Risk-adjusted average
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total Yield Generated</CardTitle>
                <Activity className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{formatCurrency(totalStats.totalYieldGenerated)}</div>
                <p className="text-xs text-muted-foreground">
                  Last 30 days
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Best Performer</CardTitle>
                <TrendingUp className="h-4 w-4 text-green-600" />
              </CardHeader>
              <CardContent>
                <div className="text-lg font-bold">{totalStats.bestPerformer}</div>
                <p className="text-xs text-muted-foreground">
                  Highest current APY
                </p>
              </CardContent>
            </Card>
          </div>

          {/* Protocol Allocation */}
          <div className="grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <PieChartIcon className="h-5 w-5" />
                  Protocol Allocation
                </CardTitle>
                <CardDescription>Current TVL distribution</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="h-[250px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={allocationData}
                        cx="50%"
                        cy="50%"
                        innerRadius={60}
                        outerRadius={100}
                        paddingAngle={5}
                        dataKey="value"
                      >
                        {allocationData.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={entry.color} />
                        ))}
                      </Pie>
                      <Tooltip formatter={(value: number) => formatCurrency(value)} />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
                <div className="grid grid-cols-2 gap-2 mt-4">
                  {allocationData.map((entry, index) => (
                    <div key={index} className="flex items-center space-x-2">
                      <div 
                        className="w-3 h-3 rounded-full" 
                        style={{ backgroundColor: entry.color }}
                      ></div>
                      <span className="text-sm">{entry.name}</span>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <BarChart3 className="h-5 w-5" />
                  Current APY Comparison
                </CardTitle>
                <CardDescription>Real-time yield rates</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="h-[250px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={protocols}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                      <YAxis tickFormatter={(value) => `${value}%`} />
                      <Tooltip formatter={(value: number) => `${value.toFixed(2)}%`} />
                      <Bar 
                        dataKey="currentAPY" 
                        fill="#3b82f6"
                        radius={[4, 4, 0, 0]}
                      />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="protocols" className="space-y-4">
          <h3 className="text-lg font-semibold">Protocol Details</h3>
          <div className="grid gap-4 md:grid-cols-2">
            {protocols.map((protocol) => (
              <Card key={protocol.name}>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-lg">{protocol.name}</CardTitle>
                    <div className="flex items-center space-x-2">
                      <Badge className={getStatusColor(protocol.status)}>
                        {protocol.status === "active" && <CheckCircle className="h-3 w-3 mr-1" />}
                        {protocol.status === "rebalancing" && <RefreshCw className="h-3 w-3 mr-1" />}
                        {protocol.status === "paused" && <AlertCircle className="h-3 w-3 mr-1" />}
                        {protocol.status}
                      </Badge>
                      <Badge variant="outline" className={getRiskColor(protocol.riskLevel)}>
                        {protocol.riskLevel} risk
                      </Badge>
                    </div>
                  </div>
                  <CardDescription>
                    {protocol.type.replace('_', ' ').toUpperCase()} Strategy
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-2 gap-4 text-sm">
                    <div>
                      <span className="text-muted-foreground">Current APY:</span>
                      <div className="font-semibold text-lg text-green-600">
                        {formatPercent(protocol.currentAPY)}
                      </div>
                    </div>
                    <div>
                      <span className="text-muted-foreground">TVL:</span>
                      <div className="font-semibold text-lg">
                        {formatCurrency(protocol.tvl)}
                      </div>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Allocation:</span>
                      <div className="font-semibold">
                        {protocol.allocation}% / {protocol.maxAllocation}%
                      </div>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Yield Generated:</span>
                      <div className="font-semibold text-green-600">
                        {formatCurrency(protocol.yieldGenerated)}
                      </div>
                    </div>
                  </div>
                  <div>
                    <span className="text-muted-foreground text-sm">Last Rebalance:</span>
                    <div className="text-sm">{formatDate(protocol.lastRebalance)}</div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </TabsContent>

        <TabsContent value="performance" className="space-y-4">
          <h3 className="text-lg font-semibold">Historical Performance (30 Days)</h3>
          <Card>
            <CardHeader>
              <CardTitle>APY Trends</CardTitle>
              <CardDescription>Protocol yield comparison over time</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="h-[400px]">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={performanceData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis 
                      dataKey="date"
                      tickFormatter={(value) => new Date(value).toLocaleDateString()}
                    />
                    <YAxis tickFormatter={(value) => `${value}%`} />
                    <Tooltip 
                      labelFormatter={(value) => new Date(value).toLocaleDateString()}
                      formatter={(value: number, name: string) => [
                        `${value.toFixed(2)}%`,
                        name === "aave" ? "Aave v3" :
                        name === "wlf" ? "WLF" :
                        name === "uniswap" ? "Uniswap V3" :
                        name === "aerodrome" ? "Aerodrome" : "Weighted Avg"
                      ]}
                    />
                    <Line type="monotone" dataKey="aave" stroke="#3b82f6" strokeWidth={2} dot={false} />
                    <Line type="monotone" dataKey="wlf" stroke="#10b981" strokeWidth={2} dot={false} />
                    <Line type="monotone" dataKey="uniswap" stroke="#f59e0b" strokeWidth={2} dot={false} />
                    <Line type="monotone" dataKey="aerodrome" stroke="#ef4444" strokeWidth={2} dot={false} />
                    <Line type="monotone" dataKey="weighted" stroke="#6b7280" strokeWidth={3} strokeDasharray="5 5" dot={false} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="rebalancing" className="space-y-4">
          <h3 className="text-lg font-semibold">Recent Rebalancing Events</h3>
          <Card>
            <CardContent className="p-0">
              <div className="divide-y">
                {rebalanceHistory.map((event) => (
                  <div key={event.id} className="p-4">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center space-x-2">
                        <Badge variant={event.status === "completed" ? "default" : "secondary"}>
                          {event.status}
                        </Badge>
                        <span className="text-sm text-muted-foreground">
                          {formatDate(event.timestamp)}
                        </span>
                      </div>
                      <div className="text-sm font-medium">
                        {formatCurrency(event.amount)}
                      </div>
                    </div>
                    <div className="space-y-1">
                      <div className="text-sm">
                        <span className="font-medium">{event.fromProtocol}</span>
                        <span className="text-muted-foreground"> ({formatPercent(event.oldAPY)}) </span>
                        <span className="mx-2">→</span>
                        <span className="font-medium">{event.toProtocol}</span>
                        <span className="text-green-600"> ({formatPercent(event.newAPY)})</span>
                      </div>
                      <div className="text-sm text-muted-foreground">
                        {event.reason}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
