"use client";

import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { 
  TrendingUp, 
  Shield, 
  Calendar, 
  DollarSign, 
  Flame, 
  Wallet,
  AlertTriangle,
  CheckCircle,
  Clock,
  BarChart3
} from "lucide-react";
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from "recharts";

interface BuybackExecution {
  id: string;
  timestamp: Date;
  usdcSpent: number;
  agnBought: number;
  agnBurned: number;
  agnToTreasury: number;
  avgPrice: number;
  twapPeriod: string;
  txHash: string;
}

interface SafetyGate {
  name: string;
  status: "healthy" | "warning" | "critical";
  currentValue: number;
  threshold: number;
  unit: string;
  description: string;
}

interface TWAPData {
  timestamp: Date;
  price: number;
  volume: number;
}

export default function BuybackTracker() {
  const [buybackHistory, setBuybackHistory] = useState<BuybackExecution[]>([]);
  const [safetyGates, setSafetyGates] = useState<SafetyGate[]>([]);
  const [twapData, setTwapData] = useState<TWAPData[]>([]);
  const [totalStats, setTotalStats] = useState({
    totalUSDCSpent: 0,
    totalAGNBought: 0,
    totalAGNBurned: 0,
    totalAGNToTreasury: 0,
    avgPrice: 0,
    burnRate: 50 // 50% burn, 50% treasury
  });

  useEffect(() => {
    // Mock data - in production, fetch from Buyback contract events
    const mockBuybacks: BuybackExecution[] = [
      {
        id: "buyback-1",
        timestamp: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
        usdcSpent: 5000,
        agnBought: 50000,
        agnBurned: 25000,
        agnToTreasury: 25000,
        avgPrice: 0.10,
        twapPeriod: "7-day",
        txHash: "0x123...abc"
      },
      {
        id: "buyback-2", 
        timestamp: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000),
        usdcSpent: 4500,
        agnBought: 47368,
        agnBurned: 23684,
        agnToTreasury: 23684,
        avgPrice: 0.095,
        twapPeriod: "7-day",
        txHash: "0x456...def"
      },
      {
        id: "buyback-3",
        timestamp: new Date(Date.now() - 21 * 24 * 60 * 60 * 1000),
        usdcSpent: 3800,
        agnBought: 42222,
        agnBurned: 21111,
        agnToTreasury: 21111,
        avgPrice: 0.09,
        twapPeriod: "7-day",
        txHash: "0x789...ghi"
      },
      {
        id: "buyback-4",
        timestamp: new Date(Date.now() - 28 * 24 * 60 * 60 * 1000),
        usdcSpent: 4200,
        agnBought: 48837,
        agnBurned: 24419,
        agnToTreasury: 24418,
        avgPrice: 0.086,
        twapPeriod: "7-day",
        txHash: "0xabc...123"
      }
    ];

    const mockSafetyGates: SafetyGate[] = [
      {
        name: "Runway Buffer",
        status: "healthy",
        currentValue: 8.5,
        threshold: 6.0,
        unit: "months",
        description: "Treasury runway for operational expenses"
      },
      {
        name: "Coverage Ratio",
        status: "healthy", 
        currentValue: 1.45,
        threshold: 1.20,
        unit: "x",
        description: "ETH treasury value vs outstanding ATN bonds"
      },
      {
        name: "Weekly DCA Limit",
        status: "warning",
        currentValue: 4800,
        threshold: 5000,
        unit: "USDC",
        description: "Remaining weekly ETH purchase capacity"
      },
      {
        name: "Liquidity Threshold",
        status: "healthy",
        currentValue: 85,
        threshold: 70,
        unit: "%",
        description: "AGN token liquidity for smooth buybacks"
      }
    ];

    const mockTWAP: TWAPData[] = [
      { timestamp: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000), price: 0.082, volume: 15000 },
      { timestamp: new Date(Date.now() - 25 * 24 * 60 * 60 * 1000), price: 0.086, volume: 18000 },
      { timestamp: new Date(Date.now() - 20 * 24 * 60 * 60 * 1000), price: 0.090, volume: 22000 },
      { timestamp: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000), price: 0.095, volume: 19000 },
      { timestamp: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000), price: 0.100, volume: 25000 },
      { timestamp: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000), price: 0.105, volume: 28000 },
      { timestamp: new Date(), price: 0.108, volume: 30000 }
    ];

    setBuybackHistory(mockBuybacks);
    setSafetyGates(mockSafetyGates);
    setTwapData(mockTWAP);

    // Calculate total stats
    const totals = mockBuybacks.reduce((acc, buyback) => ({
      totalUSDCSpent: acc.totalUSDCSpent + buyback.usdcSpent,
      totalAGNBought: acc.totalAGNBought + buyback.agnBought,
      totalAGNBurned: acc.totalAGNBurned + buyback.agnBurned,
      totalAGNToTreasury: acc.totalAGNToTreasury + buyback.agnToTreasury,
      avgPrice: 0, // Will calculate after
      burnRate: 50
    }), { totalUSDCSpent: 0, totalAGNBought: 0, totalAGNBurned: 0, totalAGNToTreasury: 0, avgPrice: 0, burnRate: 50 });

    totals.avgPrice = totals.totalUSDCSpent / totals.totalAGNBought;
    setTotalStats(totals);
  }, []);

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2
    }).format(amount);
  };

  const formatNumber = (num: number) => {
    return new Intl.NumberFormat('en-US').format(num);
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
      case "healthy": return "text-green-600 bg-green-50";
      case "warning": return "text-yellow-600 bg-yellow-50";
      case "critical": return "text-red-600 bg-red-50";
      default: return "text-gray-600 bg-gray-50";
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "healthy": return <CheckCircle className="h-4 w-4" />;
      case "warning": return <AlertTriangle className="h-4 w-4" />;
      case "critical": return <AlertTriangle className="h-4 w-4" />;
      default: return <Clock className="h-4 w-4" />;
    }
  };

  const burnTreasuryData = [
    { name: "Burned", value: totalStats.totalAGNBurned, color: "#ef4444" },
    { name: "To Treasury", value: totalStats.totalAGNToTreasury, color: "#3b82f6" }
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">AGN Buyback Tracker</h2>
          <p className="text-muted-foreground">
            Weekly TWAP buybacks with 50/50 burn/treasury split
          </p>
        </div>
        <div className="flex items-center space-x-2">
          <Flame className="h-5 w-5 text-orange-500" />
          <span className="text-sm text-muted-foreground">Deflationary</span>
        </div>
      </div>

      <Tabs defaultValue="overview" className="space-y-4">
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="safety-gates">Safety Gates</TabsTrigger>
          <TabsTrigger value="history">Execution History</TabsTrigger>
          <TabsTrigger value="twap">TWAP Tracking</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-4">
          {/* Key Stats */}
          <div className="grid gap-4 md:grid-cols-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total USDC Spent</CardTitle>
                <DollarSign className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{formatCurrency(totalStats.totalUSDCSpent)}</div>
                <p className="text-xs text-muted-foreground">
                  Across {buybackHistory.length} buybacks
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">AGN Bought</CardTitle>
                <TrendingUp className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{formatNumber(totalStats.totalAGNBought)}</div>
                <p className="text-xs text-muted-foreground">
                  Avg price: ${totalStats.avgPrice.toFixed(4)}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">AGN Burned</CardTitle>
                <Flame className="h-4 w-4 text-orange-500" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-orange-600">{formatNumber(totalStats.totalAGNBurned)}</div>
                <p className="text-xs text-muted-foreground">
                  50% burn rate
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">To Treasury</CardTitle>
                <Wallet className="h-4 w-4 text-blue-500" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-blue-600">{formatNumber(totalStats.totalAGNToTreasury)}</div>
                <p className="text-xs text-muted-foreground">
                  50% to treasury
                </p>
              </CardContent>
            </Card>
          </div>

          {/* Burn/Treasury Split Visualization */}
          <div className="grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>AGN Distribution</CardTitle>
                <CardDescription>50/50 burn/treasury split</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="h-[200px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={burnTreasuryData}
                        cx="50%"
                        cy="50%"
                        innerRadius={60}
                        outerRadius={80}
                        paddingAngle={5}
                        dataKey="value"
                      >
                        {burnTreasuryData.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={entry.color} />
                        ))}
                      </Pie>
                      <Tooltip formatter={(value: number) => formatNumber(value)} />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
                <div className="flex justify-center space-x-4 mt-2">
                  <div className="flex items-center space-x-2">
                    <div className="w-3 h-3 bg-red-500 rounded-full"></div>
                    <span className="text-sm">Burned</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
                    <span className="text-sm">To Treasury</span>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Next Buyback</CardTitle>
                <CardDescription>Scheduled execution details</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex justify-between items-center">
                  <span className="text-sm">Next Execution:</span>
                  <Badge variant="outline">
                    <Calendar className="h-3 w-3 mr-1" />
                    In 3 days
                  </Badge>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm">Estimated Amount:</span>
                  <span className="font-semibold">~$4,200</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm">Current AGN Price:</span>
                  <span className="font-semibold">$0.108</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm">Expected AGN:</span>
                  <span className="font-semibold">~38,888 AGN</span>
                </div>
                <div className="pt-2 border-t">
                  <div className="flex justify-between items-center text-sm">
                    <span>Will Burn:</span>
                    <span className="text-orange-600 font-semibold">~19,444 AGN</span>
                  </div>
                  <div className="flex justify-between items-center text-sm">
                    <span>To Treasury:</span>
                    <span className="text-blue-600 font-semibold">~19,444 AGN</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="safety-gates" className="space-y-4">
          <h3 className="text-lg font-semibold">Safety Gate Status</h3>
          <div className="grid gap-4 md:grid-cols-2">
            {safetyGates.map((gate) => (
              <Card key={gate.name}>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-lg">{gate.name}</CardTitle>
                    <Badge className={getStatusColor(gate.status)}>
                      {getStatusIcon(gate.status)}
                      {gate.status}
                    </Badge>
                  </div>
                  <CardDescription>{gate.description}</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span>Current:</span>
                      <span className="font-semibold">
                        {gate.currentValue} {gate.unit}
                      </span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span>Threshold:</span>
                      <span>{gate.threshold} {gate.unit}</span>
                    </div>
                    <Progress 
                      value={Math.min((gate.currentValue / gate.threshold) * 100, 100)}
                      className="h-2"
                    />
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </TabsContent>

        <TabsContent value="history" className="space-y-4">
          <h3 className="text-lg font-semibold">Buyback Execution History</h3>
          <Card>
            <CardContent className="p-0">
              <div className="divide-y">
                {buybackHistory.map((buyback) => (
                  <div key={buyback.id} className="p-4">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center space-x-2">
                        <Badge variant="outline">{buyback.twapPeriod} TWAP</Badge>
                        <span className="text-sm text-muted-foreground">
                          {formatDate(buyback.timestamp)}
                        </span>
                      </div>
                      <div className="text-sm text-muted-foreground">
                        Tx: {buyback.txHash}
                      </div>
                    </div>
                    <div className="grid grid-cols-2 md:grid-cols-5 gap-4 text-sm">
                      <div>
                        <span className="text-muted-foreground">USDC Spent:</span>
                        <div className="font-semibold">{formatCurrency(buyback.usdcSpent)}</div>
                      </div>
                      <div>
                        <span className="text-muted-foreground">AGN Bought:</span>
                        <div className="font-semibold">{formatNumber(buyback.agnBought)}</div>
                      </div>
                      <div>
                        <span className="text-muted-foreground">AGN Burned:</span>
                        <div className="font-semibold text-orange-600">{formatNumber(buyback.agnBurned)}</div>
                      </div>
                      <div>
                        <span className="text-muted-foreground">To Treasury:</span>
                        <div className="font-semibold text-blue-600">{formatNumber(buyback.agnToTreasury)}</div>
                      </div>
                      <div>
                        <span className="text-muted-foreground">Avg Price:</span>
                        <div className="font-semibold">${buyback.avgPrice.toFixed(4)}</div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="twap" className="space-y-4">
          <h3 className="text-lg font-semibold">TWAP Price Tracking</h3>
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <BarChart3 className="h-5 w-5" />
                AGN Price & Volume (30 Days)
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={twapData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis 
                      dataKey="timestamp"
                      tickFormatter={(value) => new Date(value).toLocaleDateString()}
                    />
                    <YAxis 
                      yAxisId="price"
                      orientation="left"
                      tickFormatter={(value) => `$${value.toFixed(3)}`}
                    />
                    <YAxis 
                      yAxisId="volume"
                      orientation="right"
                      tickFormatter={(value) => `${(value/1000).toFixed(0)}K`}
                    />
                    <Tooltip 
                      labelFormatter={(value) => new Date(value).toLocaleDateString()}
                      formatter={(value: number, name: string) => [
                        name === "price" ? `$${value.toFixed(4)}` : formatNumber(value),
                        name === "price" ? "Price" : "Volume"
                      ]}
                    />
                    <Line 
                      yAxisId="price"
                      type="monotone" 
                      dataKey="price" 
                      stroke="#3b82f6" 
                      strokeWidth={2}
                      dot={false}
                    />
                    <Line 
                      yAxisId="volume"
                      type="monotone" 
                      dataKey="volume" 
                      stroke="#10b981" 
                      strokeWidth={1}
                      strokeDasharray="5 5"
                      dot={false}
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
