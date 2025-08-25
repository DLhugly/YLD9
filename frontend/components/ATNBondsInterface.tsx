"use client";

import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Calculator, Clock, DollarSign, TrendingUp, Shield, Calendar } from "lucide-react";

interface ATNTranche {
  id: string;
  name: string;
  apr: number;
  duration: number; // months
  maxCap: number;
  currentSubscribed: number;
  minSubscription: number;
  asset: string;
  maturityDate: Date;
  isActive: boolean;
}

interface UserBond {
  id: string;
  trancheId: string;
  trancheName: string;
  amount: number;
  asset: string;
  subscriptionDate: Date;
  maturityDate: Date;
  apr: number;
  couponsPaid: number;
  nextCouponDate: Date;
  totalReturn: number;
  status: "active" | "matured" | "redeemed";
}

interface CouponPayment {
  id: string;
  bondId: string;
  amount: number;
  date: Date;
  status: "paid" | "pending";
}

export default function ATNBondsInterface() {
  const [availableTranches, setAvailableTranches] = useState<ATNTranche[]>([]);
  const [userBonds, setUserBonds] = useState<UserBond[]>([]);
  const [couponHistory, setCouponHistory] = useState<CouponPayment[]>([]);
  const [selectedTranche, setSelectedTranche] = useState<string>("");
  const [subscriptionAmount, setSubscriptionAmount] = useState<string>("");
  const [calculatedYield, setCalculatedYield] = useState<number>(0);

  // Mock data - in production, fetch from contracts
  useEffect(() => {
    const mockTranches: ATNTranche[] = [
      {
        id: "atn-01",
        name: "ATN-01",
        apr: 8.0,
        duration: 6,
        maxCap: 250000,
        currentSubscribed: 180000,
        minSubscription: 1000,
        asset: "USDC",
        maturityDate: new Date(Date.now() + 6 * 30 * 24 * 60 * 60 * 1000),
        isActive: true
      },
      {
        id: "atn-02",
        name: "ATN-02",
        apr: 10.0,
        duration: 12,
        maxCap: 500000,
        currentSubscribed: 320000,
        minSubscription: 2000,
        asset: "USD1",
        maturityDate: new Date(Date.now() + 12 * 30 * 24 * 60 * 60 * 1000),
        isActive: true
      },
      {
        id: "atn-03",
        name: "ATN-03",
        apr: 6.5,
        duration: 3,
        maxCap: 150000,
        currentSubscribed: 95000,
        minSubscription: 500,
        asset: "EURC",
        maturityDate: new Date(Date.now() + 3 * 30 * 24 * 60 * 60 * 1000),
        isActive: true
      }
    ];

    const mockUserBonds: UserBond[] = [
      {
        id: "bond-1",
        trancheId: "atn-01",
        trancheName: "ATN-01",
        amount: 5000,
        asset: "USDC",
        subscriptionDate: new Date(Date.now() - 60 * 24 * 60 * 60 * 1000),
        maturityDate: new Date(Date.now() + 120 * 24 * 60 * 60 * 1000),
        apr: 8.0,
        couponsPaid: 2,
        nextCouponDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        totalReturn: 200,
        status: "active"
      },
      {
        id: "bond-2",
        trancheId: "atn-02",
        trancheName: "ATN-02",
        amount: 10000,
        asset: "USD1",
        subscriptionDate: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
        maturityDate: new Date(Date.now() + 330 * 24 * 60 * 60 * 1000),
        apr: 10.0,
        couponsPaid: 1,
        nextCouponDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        totalReturn: 83.33,
        status: "active"
      }
    ];

    const mockCoupons: CouponPayment[] = [
      {
        id: "coupon-1",
        bondId: "bond-1",
        amount: 33.33,
        date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
        status: "paid"
      },
      {
        id: "coupon-2",
        bondId: "bond-1",
        amount: 33.33,
        date: new Date(Date.now() - 60 * 24 * 60 * 60 * 1000),
        status: "paid"
      },
      {
        id: "coupon-3",
        bondId: "bond-2",
        amount: 83.33,
        date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
        status: "paid"
      },
      {
        id: "coupon-4",
        bondId: "bond-1",
        amount: 33.33,
        date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        status: "pending"
      }
    ];

    setAvailableTranches(mockTranches);
    setUserBonds(mockUserBonds);
    setCouponHistory(mockCoupons);
  }, []);

  // Calculate yield when inputs change
  useEffect(() => {
    if (selectedTranche && subscriptionAmount) {
      const tranche = availableTranches.find(t => t.id === selectedTranche);
      if (tranche) {
        const amount = parseFloat(subscriptionAmount);
        const monthlyYield = (amount * tranche.apr / 100) / 12;
        const totalYield = monthlyYield * tranche.duration;
        setCalculatedYield(totalYield);
      }
    }
  }, [selectedTranche, subscriptionAmount, availableTranches]);

  const handleSubscription = async () => {
    if (!selectedTranche || !subscriptionAmount) return;
    
    // In production: call BondManager.subscribe()
    console.log("Subscribing to tranche:", selectedTranche, "Amount:", subscriptionAmount);
    // Mock success
    alert(`Successfully subscribed to ${selectedTranche} with ${subscriptionAmount} tokens!`);
  };

  const formatCurrency = (amount: number, asset: string = "USD") => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: asset === "EURC" ? "EUR" : "USD",
      minimumFractionDigits: 2
    }).format(amount);
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Agonic Treasury Notes (ATN)</h2>
          <p className="text-muted-foreground">
            Fixed-APR multi-stablecoin bonds backed by ETH treasury
          </p>
        </div>
        <div className="flex items-center space-x-2">
          <Shield className="h-5 w-5 text-green-500" />
          <span className="text-sm text-muted-foreground">Treasury Backed</span>
        </div>
      </div>

      <Tabs defaultValue="subscribe" className="space-y-4">
        <TabsList>
          <TabsTrigger value="subscribe">Subscribe to ATN</TabsTrigger>
          <TabsTrigger value="portfolio">My Bonds</TabsTrigger>
          <TabsTrigger value="history">Coupon History</TabsTrigger>
          <TabsTrigger value="calculator">Yield Calculator</TabsTrigger>
        </TabsList>

        <TabsContent value="subscribe" className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            {/* Available Tranches */}
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Available Tranches</h3>
              {availableTranches.map((tranche) => (
                <Card 
                  key={tranche.id} 
                  className={`cursor-pointer transition-colors ${
                    selectedTranche === tranche.id ? 'ring-2 ring-primary' : ''
                  }`}
                  onClick={() => setSelectedTranche(tranche.id)}
                >
                  <CardHeader className="pb-2">
                    <div className="flex items-center justify-between">
                      <CardTitle className="text-lg">{tranche.name}</CardTitle>
                      <Badge variant="secondary">{tranche.asset}</Badge>
                    </div>
                    <CardDescription>
                      {tranche.duration} months • {tranche.apr}% APR
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span>Subscribed:</span>
                        <span>{formatCurrency(tranche.currentSubscribed)} / {formatCurrency(tranche.maxCap)}</span>
                      </div>
                      <Progress 
                        value={(tranche.currentSubscribed / tranche.maxCap) * 100} 
                        className="h-2"
                      />
                      <div className="flex justify-between text-sm text-muted-foreground">
                        <span>Min: {formatCurrency(tranche.minSubscription)}</span>
                        <span>Maturity: {formatDate(tranche.maturityDate)}</span>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>

            {/* Subscription Form */}
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Subscribe to ATN</h3>
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <DollarSign className="h-5 w-5" />
                    Bond Subscription
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <label className="text-sm font-medium">Select Tranche</label>
                    <Select value={selectedTranche} onValueChange={setSelectedTranche}>
                      <SelectTrigger>
                        <SelectValue placeholder="Choose a tranche" />
                      </SelectTrigger>
                      <SelectContent>
                        {availableTranches.map((tranche) => (
                          <SelectItem key={tranche.id} value={tranche.id}>
                            {tranche.name} - {tranche.apr}% APR ({tranche.duration}m)
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  <div>
                    <label className="text-sm font-medium">Subscription Amount</label>
                    <Input
                      type="number"
                      placeholder="Enter amount"
                      value={subscriptionAmount}
                      onChange={(e) => setSubscriptionAmount(e.target.value)}
                    />
                  </div>

                  {calculatedYield > 0 && (
                    <div className="p-3 bg-muted rounded-lg">
                      <div className="flex justify-between items-center">
                        <span className="text-sm">Expected Total Yield:</span>
                        <span className="font-semibold text-green-600">
                          +{formatCurrency(calculatedYield)}
                        </span>
                      </div>
                    </div>
                  )}

                  <Button 
                    onClick={handleSubscription}
                    disabled={!selectedTranche || !subscriptionAmount}
                    className="w-full"
                  >
                    Subscribe to ATN
                  </Button>
                </CardContent>
              </Card>
            </div>
          </div>
        </TabsContent>

        <TabsContent value="portfolio" className="space-y-4">
          <h3 className="text-lg font-semibold">My Active Bonds</h3>
          <div className="grid gap-4 md:grid-cols-2">
            {userBonds.map((bond) => (
              <Card key={bond.id}>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-lg">{bond.trancheName}</CardTitle>
                    <Badge variant={bond.status === "active" ? "default" : "secondary"}>
                      {bond.status}
                    </Badge>
                  </div>
                  <CardDescription>
                    {formatCurrency(bond.amount, bond.asset)} • {bond.apr}% APR
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3">
                    <div className="flex justify-between text-sm">
                      <span>Subscription Date:</span>
                      <span>{formatDate(bond.subscriptionDate)}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span>Maturity Date:</span>
                      <span>{formatDate(bond.maturityDate)}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span>Coupons Paid:</span>
                      <span>{bond.couponsPaid}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span>Next Coupon:</span>
                      <span>{formatDate(bond.nextCouponDate)}</span>
                    </div>
                    <div className="flex justify-between text-sm font-semibold">
                      <span>Total Return:</span>
                      <span className="text-green-600">+{formatCurrency(bond.totalReturn)}</span>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </TabsContent>

        <TabsContent value="history" className="space-y-4">
          <h3 className="text-lg font-semibold">Coupon Payment History</h3>
          <Card>
            <CardContent className="p-0">
              <div className="divide-y">
                {couponHistory.map((coupon) => {
                  const bond = userBonds.find(b => b.id === coupon.bondId);
                  return (
                    <div key={coupon.id} className="p-4 flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        <div className={`w-2 h-2 rounded-full ${
                          coupon.status === "paid" ? "bg-green-500" : "bg-yellow-500"
                        }`} />
                        <div>
                          <div className="font-medium">{bond?.trancheName}</div>
                          <div className="text-sm text-muted-foreground">
                            {formatDate(coupon.date)}
                          </div>
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="font-medium">
                          +{formatCurrency(coupon.amount)}
                        </div>
                        <div className="text-sm text-muted-foreground">
                          {coupon.status === "paid" ? "Paid" : "Pending"}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="calculator" className="space-y-4">
          <h3 className="text-lg font-semibold">ATN Yield Calculator</h3>
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Calculator className="h-5 w-5" />
                Calculate Your Returns
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-4 md:grid-cols-3">
                <div>
                  <label className="text-sm font-medium">Investment Amount</label>
                  <Input
                    type="number"
                    placeholder="10000"
                    value={subscriptionAmount}
                    onChange={(e) => setSubscriptionAmount(e.target.value)}
                  />
                </div>
                <div>
                  <label className="text-sm font-medium">APR (%)</label>
                  <Input
                    type="number"
                    placeholder="8.0"
                    defaultValue="8.0"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium">Duration (months)</label>
                  <Input
                    type="number"
                    placeholder="6"
                    defaultValue="6"
                  />
                </div>
              </div>
              
              {subscriptionAmount && (
                <div className="p-4 bg-muted rounded-lg space-y-2">
                  <div className="flex justify-between">
                    <span>Monthly Coupon:</span>
                    <span className="font-semibold">
                      {formatCurrency((parseFloat(subscriptionAmount) * 8 / 100) / 12)}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>Total Interest (6 months):</span>
                    <span className="font-semibold text-green-600">
                      {formatCurrency((parseFloat(subscriptionAmount) * 8 / 100) / 2)}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>Final Amount:</span>
                    <span className="font-bold text-lg">
                      {formatCurrency(parseFloat(subscriptionAmount) + (parseFloat(subscriptionAmount) * 8 / 100) / 2)}
                    </span>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
