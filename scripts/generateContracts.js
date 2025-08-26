#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Contract addresses (these would come from deployment)
const CONTRACT_ADDRESSES = {
  // Core Protocol - Ultra-Simple Treasury
  Treasury: "0x1234567890123456789012345678901234567891",
  SimpleBond: "0x1234567890123456789012345678901234567892", 
  StakingVault: "0x1234567890123456789012345678901234567893",
  Buyback: "0x1234567890123456789012345678901234567894",
  
  // Protocol Adapters
  AaveAdapter: "0x1234567890123456789012345678901234567895",
  LidoAdapter: "0x1234567890123456789012345678901234567896",
  
  // Utilities
  AttestationEmitter: "0x1234567890123456789012345678901234567897",
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
    Treasury: [
      "function getTotalTreasuryValue() view returns (uint256)",
      "function liquidETH() view returns (uint256)",
      "function stakedETH() view returns (uint256)",
      "function getSafetyGateStatus() view returns (bool runwayOK, bool crOK)",
      "function getRunwayMonths() view returns (uint256)",
      "function getCoverageRatio() view returns (uint256)",
      "function getCurrentETHPrice() view returns (uint256)",
      "function getAGNPrice() view returns (uint256)",
      "function processInflowAutomated(uint256 totalInflow)",
      "function checkUpkeep(bytes calldata checkData) view returns (bool upkeepNeeded, bytes memory performData)",
      "function performUpkeep(bytes calldata performData)",
      "event AutomatedHarvest(uint256 totalYield, uint256 timestamp)",
      "event AutomatedDCA(uint256 usdcAmount, uint256 ethAmount, uint256 ethPrice, uint256 timestamp)"
    ],
    
    SimpleBond: [
      "function purchaseBond(uint256 usdcAmount)",
      "function claimBond(uint256 bondId)",
      "function getUserBonds(address user) view returns (tuple[] memory)",
      "function getUserBondCount(address user) view returns (uint256)",
      "function getWeeklyCapRemaining() view returns (uint256)",
      "function getBondInfo(uint256 bondId) view returns (tuple memory)",
      "event BondPurchased(address indexed user, uint256 indexed bondId, uint256 usdcAmount, uint256 agnAmount, uint256 vestingEnd)",
      "event BondClaimed(address indexed user, uint256 indexed bondId, uint256 agnAmount)"
    ],
    
    StakingVault: [
      "function totalAssets() view returns (uint256)",
      "function totalSupply() view returns (uint256)", 
      "function balanceOf(address) view returns (uint256)",
      "function deposit(uint256 assets, address receiver) returns (uint256 shares)",
      "function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares)",
      "function previewDeposit(uint256 assets) view returns (uint256 shares)",
      "function previewWithdraw(uint256 assets) view returns (uint256 shares)",
      "function getUserYieldBoost(address user) view returns (uint256)",
      "function harvest() returns (uint256 totalYield)",
      "event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares)",
      "event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares)",
      "event YieldHarvested(uint256 totalYield, uint256 timestamp)"
    ],
    
    Buyback: [
      "function buybackPool() view returns (uint256)",
      "function getSafetyGateStatus() view returns (bool canExecute, bool runwayOK, bool crOK, bool liquidityOK, bool volumeOK)",
      "function totalAGNBought() view returns (uint256)",
      "function totalAGNBurned() view returns (uint256)",
      "function totalUSDCSpent() view returns (uint256)",
      "function lastBuybackTime() view returns (uint256)",
      "function executeBuyback()",
      "function fundBuybackPool(uint256 amount)",
      "function addLiquidity()",
      "function claimPoolFees() returns (uint256)",
      "event BuybackExecuted(uint256 usdcSpent, uint256 agnBought, uint256 agnBurned, uint256 agnForLP)",
      "event LiquidityAdded(uint256 agnAmount, uint256 usdcAmount, uint256 lpTokens)"
    ],
    
    AaveAdapter: [
      "function deposit(uint256 amount) returns (uint256)",
      "function withdraw(uint256 amount) returns (uint256)",
      "function harvest() returns (uint256)",
      "function getBalance() view returns (uint256)",
      "function getCurrentAPY() view returns (uint256)",
      "event Deposited(uint256 amount, uint256 aTokensReceived)",
      "event Withdrawn(uint256 amount, uint256 aTokensBurned)",
      "event YieldHarvested(uint256 amount)"
    ],
    
    LidoAdapter: [
      "function deposit(uint256 amount) payable returns (uint256)",
      "function withdraw(uint256 amount) returns (uint256)",
      "function harvest() returns (uint256)",
      "function getBalance() view returns (uint256)",
      "function getCurrentAPY() view returns (uint256)",
      "event Deposited(uint256 amount, uint256 stTokensReceived)",
      "event Withdrawn(uint256 amount, uint256 stTokensBurned)",
      "event YieldHarvested(uint256 amount)"
    ],
    
    AttestationEmitter: [
      "function attest(bytes32 schema, bytes calldata data)",
      "function getAttestation(bytes32 uid) view returns (tuple memory)",
      "event AttestationMade(bytes32 indexed uid, bytes32 indexed schema, address indexed attester, bytes data)"
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
  
  // Base Mainnet (8453)
  contracts[8453] = {};
  
  // Add contracts for Base mainnet
  for (const [contractName, address] of Object.entries(CONTRACT_ADDRESSES)) {
    const abi = readABI(contractName);
    
    contracts[8453][contractName] = {
      address: address,
      abi: abi
    };
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
