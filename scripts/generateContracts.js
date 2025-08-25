#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Contract addresses (these would come from deployment)
const CONTRACT_ADDRESSES = {
  // Core Protocol
  StableVault4626: "0x1234567890123456789012345678901234567890",
  Treasury: "0x1234567890123456789012345678901234567891", 
  TreasuryManager: "0x1234567890123456789012345678901234567892",
  BondManager: "0x1234567890123456789012345678901234567893",
  Buyback: "0x1234567890123456789012345678901234567894",
  Gov: "0x1234567890123456789012345678901234567895",
  
  // Protocol Adapters
  AaveAdapter: "0x1234567890123456789012345678901234567896",
  WLFAdapter: "0x1234567890123456789012345678901234567897",
  UniswapAdapter: "0x1234567890123456789012345678901234567898",
  AerodromeAdapter: "0x1234567890123456789012345678901234567899",
  
  // Phase 1 Features
  LPStaking: "0x123456789012345678901234567890123456789a",
  POLManager: "0x123456789012345678901234567890123456789b", 
  KeeperRegistry: "0x123456789012345678901234567890123456789c",
  AttestationEmitter: "0x123456789012345678901234567890123456789d",
};

// Read ABI from Foundry build artifacts
function readABI(contractName) {
  try {
    const artifactPath = path.join(__dirname, `../contracts/out/${contractName}.sol/${contractName}.json`);
    if (!fs.existsSync(artifactPath)) {
      console.warn(`⚠️  Artifact not found for ${contractName}, using minimal ABI`);
      return getMinimalABI(contractName);
    }
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
    return artifact.abi;
  } catch (error) {
    console.warn(`⚠️  Error reading ABI for ${contractName}, using minimal ABI:`, error.message);
    return getMinimalABI(contractName);
  }
}

// Minimal ABIs for development (until contracts are deployed)
function getMinimalABI(contractName) {
  const commonABIs = {
    StableVault4626: [
      "function totalAssets() view returns (uint256)",
      "function totalSupply() view returns (uint256)", 
      "function balanceOf(address) view returns (uint256)",
      "function deposit(uint256 assets, address receiver) returns (uint256 shares)",
      "function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares)",
      "function previewDeposit(uint256 assets) view returns (uint256 shares)",
      "function previewWithdraw(uint256 assets) view returns (uint256 shares)",
      "event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares)",
      "event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares)"
    ],
    
    Treasury: [
      "function getTotalTreasuryValue() view returns (uint256)",
      "function liquidETH() view returns (uint256)",
      "function stakedETH() view returns (uint256)",
      "function getSafetyGateStatus() view returns (bool runwayOK, bool crOK)",
      "function getRunwayMonths() view returns (uint256)",
      "function getCoverageRatio() view returns (uint256)",
      "function calculateTPT() view returns (uint256 tptValue, uint256 totalValue, uint256 supply)",
      "function getLatestTPT() view returns (uint256 tptValue, uint256 timestamp)",
      "function publishTPT()",
      "event TPTPublished(uint256 tptValue, uint256 totalTreasuryValue, uint256 circulatingSupply, uint256 timestamp)"
    ],
    
    Buyback: [
      "function buybackPool() view returns (uint256)",
      "function getSafetyGateStatus() view returns (bool canExecute, bool runwayOK, bool crOK, bool liquidityOK, bool volumeOK)",
      "function totalAGNBought() view returns (uint256)",
      "function totalAGNBurned() view returns (uint256)",
      "function totalUSDCSpent() view returns (uint256)",
      "function lastBuybackTime() view returns (uint256)",
      "function executeBuyback()",
      "function getBuybackStats() view returns (tuple)",
      "function getRecentBuybacks(uint256 count) view returns (tuple[] memory)",
      "event BuybackExecuted(uint256 usdcSpent, uint256 agnBought, uint256 agnBurned, uint256 agnToTreasury)"
    ],
    
    BondManager: [
      "function getTranches() view returns (tuple[] memory)",
      "function getTrancheInfo(string memory name) view returns (tuple memory)",
      "function subscribe(string memory trancheName, address asset, uint256 amount) payable",
      "function getActiveSubscriptions(address user) view returns (tuple[] memory)",
      "function claimCoupon(string memory trancheName)",
      "function redeem(string memory trancheName)",
      "event TrancheCreated(string name, uint256 apr, uint256 duration, uint256 cap)",
      "event Subscribed(address indexed user, string trancheName, uint256 amount, uint256 shares)"
    ],
    
    LPStaking: [
      "function totalSupply() view returns (uint256)",
      "function balanceOf(address account) view returns (uint256)",
      "function earned(address account) view returns (uint256)",
      "function rewardRate() view returns (uint256)",
      "function weeklyBudget() view returns (uint256)",
      "function poolCap() view returns (uint256)",
      "function stake(uint256 amount)",
      "function withdraw(uint256 amount)",
      "function getReward()",
      "function exit()",
      "function getStakingStats() view returns (tuple memory)",
      "function getUserInfo(address user) view returns (tuple memory)",
      "event Staked(address indexed user, uint256 amount)",
      "event Withdrawn(address indexed user, uint256 amount)",
      "event RewardPaid(address indexed user, uint256 reward)"
    ],
    
    POLManager: [
      "function totalLPTokens() view returns (uint256)",
      "function getCurrentPoolOwnership() view returns (uint256)",
      "function targetOwnership() view returns (uint256)",
      "function dailyBudget() view returns (uint256)",
      "function getPOLStats() view returns (tuple memory)",
      "function addLiquidity(uint256 agnAmount, uint256 usdcAmount)",
      "event LiquidityAdded(uint256 agnAmount, uint256 usdcAmount, uint256 lpTokens, uint256 poolOwnership)"
    ],
    
    KeeperRegistry: [
      "function getKeeperStats() view returns (tuple memory)",
      "function getRecentExecutions(uint256 count) view returns (tuple[] memory)",
      "function dryRun(string calldata functionName) view returns (bool wouldSucceed, string memory reason)",
      "function executeWeeklyDCA()",
      "function executeWeeklyBuyback()",
      "function payWeeklyCoupons()",
      "function executeRebalancing()",
      "function publishWeeklyTPT()",
      "event KeeperExecuted(string functionName, address keeper, bool success, uint256 gasUsed)"
    ],
    
    TreasuryManager: [
      "function totalAUM() view returns (uint256)",
      "function getIdleBufferStatus() view returns (bool isValid, uint256 currentBuffer)",
      "function getAllProtocolInfo() view returns (tuple[] memory)",
      "function executeRebalancing()",
      "function harvestAll() returns (uint256 totalYield)",
      "event Rebalanced(string protocol, uint256 oldAllocation, uint256 newAllocation)",
      "event YieldHarvested(string protocol, uint256 amount)"
    ]
  };
  
  return commonABIs[contractName] || [
    "function name() view returns (string)",
    "function symbol() view returns (string)"
  ];
}

// Generate the deployedContracts.ts file
function generateDeployedContracts() {
  console.log('🏗️  Generating deployedContracts.ts for Agonic Protocol...');
  
  const contracts = {};
  
  // Base Sepolia (testnet)
  contracts[84532] = {
    name: "baseSepolia",
    chainId: "84532",
    contracts: {}
  };
  
  // Base Mainnet
  contracts[8453] = {
    name: "base", 
    chainId: "8453",
    contracts: {}
  };
  
  // Add contracts to both networks
  for (const [contractName, address] of Object.entries(CONTRACT_ADDRESSES)) {
    const abi = readABI(contractName);
    
    const contractConfig = {
      address: address,
      abi: abi
    };
    
    contracts[84532].contracts[contractName] = contractConfig;
    contracts[8453].contracts[contractName] = contractConfig;
  }
  
  const output = `/**
 * This file is autogenerated by Scaffold-ETH.
 * You should not edit it manually or your changes might be overwritten.
 */
import { GenericContractsDeclaration } from "~~/utils/scaffold-eth/contract";

const deployedContracts = ${JSON.stringify(contracts, null, 2)} as const;

export default deployedContracts satisfies GenericContractsDeclaration;
`;

  const outputPath = path.join(__dirname, '../frontend/contracts/deployedContracts.ts');
  fs.writeFileSync(outputPath, output);
  
  console.log('✅ Generated deployedContracts.ts with', Object.keys(CONTRACT_ADDRESSES).length, 'contracts');
  console.log('📍 File location:', outputPath);
}

// Run the generator
if (require.main === module) {
  generateDeployedContracts();
}

module.exports = { generateDeployedContracts };
