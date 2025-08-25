// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/StableVault4626.sol";
import "../src/Treasury.sol";
import "../src/TreasuryManager.sol";
import "../src/BondManager.sol";
import "../src/Buyback.sol";
import "../src/Gov.sol";
import "../src/AttestationEmitter.sol";
import "../src/adapters/AaveAdapter.sol";
import "../src/adapters/WLFAdapter.sol";
import "../src/adapters/UniswapAdapter.sol";
import "../src/adapters/AerodromeAdapter.sol";
import "../src/LPStaking.sol";
import "../src/POLManager.sol";
import "../src/KeeperRegistry.sol";

/**
 * @title DeployAgonic
 * @notice Deployment script for Agonic v1 core contracts
 */
contract DeployAgonic is Script {
    // Base L2 addresses (these would be real addresses on Base)
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC
    address constant USD1 = address(0x1); // Placeholder for USD1
    address constant EURC = address(0x2); // Placeholder for EURC  
    address constant WETH = 0x4200000000000000000000000000000000000006; // Base WETH

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Agonic v1 contracts to Base L2...");
        console.log("Deployer:", vm.addr(deployerPrivateKey));

        // 1. Deploy TreasuryManager
        console.log("Deploying TreasuryManager...");
        TreasuryManager treasuryManager = new TreasuryManager();
        console.log("TreasuryManager deployed at:", address(treasuryManager));

        // 2. Deploy Treasury
        console.log("Deploying Treasury...");
        Treasury treasury = new Treasury(USDC, USD1, EURC, WETH);
        console.log("Treasury deployed at:", address(treasury));

        // 3. Deploy StableVault4626
        console.log("Deploying StableVault4626...");
        StableVault4626 vault = new StableVault4626(
            USDC,
            "Agonic Stable Vault",
            "AGV",
            address(treasuryManager),
            address(treasury)
        );
        console.log("StableVault4626 deployed at:", address(vault));

        // 4. Deploy AGN token (mock for testing)
        console.log("Deploying mock AGN token...");
        // In production: deploy actual AGN token contract
        address AGN_TOKEN = address(0x4); // Mock AGN token address
        
        // 5. Deploy BondManager
        console.log("Deploying BondManager...");
        BondManager bondManager = new BondManager(address(treasury));
        console.log("BondManager deployed at:", address(bondManager));

        // 6. Deploy Buyback contract
        console.log("Deploying Buyback...");
        Buyback buyback = new Buyback(
            AGN_TOKEN,
            USDC,
            address(treasury),
            address(0x5) // Mock DEX router
        );
        console.log("Buyback deployed at:", address(buyback));

        // 7. Deploy Governance
        console.log("Deploying Governance...");
        Gov governance = new Gov(AGN_TOKEN);
        console.log("Governance deployed at:", address(governance));

        // 8. Deploy AttestationEmitter
        console.log("Deploying AttestationEmitter...");
        AttestationEmitter attestationEmitter = new AttestationEmitter();
        console.log("AttestationEmitter deployed at:", address(attestationEmitter));

        // 9. Deploy Protocol Adapters
        console.log("Deploying AaveAdapter...");
        AaveAdapter aaveAdapter = new AaveAdapter();
        console.log("AaveAdapter deployed at:", address(aaveAdapter));

        console.log("Deploying WLFAdapter...");
        WLFAdapter wlfAdapter = new WLFAdapter(address(treasuryManager));
        console.log("WLFAdapter deployed at:", address(wlfAdapter));

        console.log("Deploying UniswapAdapter...");
        UniswapAdapter uniswapAdapter = new UniswapAdapter(address(treasuryManager));
        console.log("UniswapAdapter deployed at:", address(uniswapAdapter));

        console.log("Deploying AerodromeAdapter...");
        AerodromeAdapter aerodromeAdapter = new AerodromeAdapter(address(treasuryManager));
        console.log("AerodromeAdapter deployed at:", address(aerodromeAdapter));

        // 10. Deploy LP Staking
        console.log("Deploying LPStaking...");
        LPStaking lpStaking = new LPStaking(
            address(0x3), // Placeholder for Aerodrome AGN/USDC LP token
            AGN_TOKEN,    // AGN token address
            address(treasury)
        );
        console.log("LPStaking deployed at:", address(lpStaking));

        // 11. Deploy POL Manager
        console.log("Deploying POLManager...");
        POLManager polManager = new POLManager(
            AGN_TOKEN,    // AGN token address
            USDC,         // USDC address
            address(treasury),
            address(0x5), // Placeholder for Aerodrome AGN/USDC pool
            address(0x6)  // Placeholder for Aerodrome gauge
        );
        console.log("POLManager deployed at:", address(polManager));

        // 12. Deploy Keeper Registry
        console.log("Deploying KeeperRegistry...");
        KeeperRegistry keeperRegistry = new KeeperRegistry(
            address(treasury),
            address(buyback),
            address(bondManager),
            address(treasuryManager),
            address(attestationEmitter)
        );
        console.log("KeeperRegistry deployed at:", address(keeperRegistry));

        // 13. Configure contracts
        console.log("Configuring contracts...");
        
        // Add supported assets to vault
        vault.addAsset(USD1);
        vault.addAsset(EURC);
        
        // Add supported assets to treasury manager
        treasuryManager.addSupportedAsset(USDC);
        treasuryManager.addSupportedAsset(USD1);
        treasuryManager.addSupportedAsset(EURC);

        // Set attestation emitter and vault address
        treasuryManager.setAttestationEmitter(address(attestationEmitter));
        treasuryManager.setVaultAddress(address(vault));

        // Set AGN token in Treasury for TPT calculations
        treasury.setAGNToken(AGN_TOKEN);

        // Configure AttestationEmitter with authorized emitters
        attestationEmitter.addAuthorizedEmitter(address(treasuryManager));
        attestationEmitter.addAuthorizedEmitter(address(treasury));
        attestationEmitter.addAuthorizedEmitter(address(buyback));
        attestationEmitter.addAuthorizedEmitter(address(bondManager));
        attestationEmitter.addAuthorizedEmitter(address(polManager));

        // Set attestation emitter in POL Manager
        polManager.setAttestationEmitter(address(attestationEmitter));

        // Add all protocol adapters with proper types
        treasuryManager.addProtocolWithType("Aave", address(aaveAdapter), 6000, TreasuryManager.ProtocolType.LENDING);
        treasuryManager.addProtocolWithType("WLF", address(wlfAdapter), 4000, TreasuryManager.ProtocolType.LENDING);
        treasuryManager.addProtocolWithType("Uniswap", address(uniswapAdapter), 3000, TreasuryManager.ProtocolType.UNISWAP_V3);
        treasuryManager.addProtocolWithType("Aerodrome", address(aerodromeAdapter), 3000, TreasuryManager.ProtocolType.AERODROME);

        // Add supported assets to bond manager
        bondManager.addSupportedAsset(USDC);
        bondManager.addSupportedAsset(USD1);
        bondManager.addSupportedAsset(EURC);

        // Create ATN-01 tranche
        bondManager.createTranche(
            "ATN-01",
            8e16, // 8% APR
            6,    // 6 months
            250000e6, // $250k cap
            USDC
        );

        // Set initial parameters (from roadmap)
        treasury.updateMonthlyOpex(50000e6); // $50k monthly OPEX
        treasury.updateWeeklyDCACap(5000e6);  // $5k weekly DCA cap
        treasury.updateFXArbThreshold(10);    // 0.1% FX arbitrage threshold
        treasury.updateETHStakingLimit(2000); // 20% ETH staking limit

        console.log("\\n=== AGONIC v1 PHASE 1 DEPLOYMENT COMPLETE ===");
        console.log("Core Contracts:");
        console.log("- Vault:", address(vault));
        console.log("- Treasury:", address(treasury));
        console.log("- TreasuryManager:", address(treasuryManager));
        console.log("- BondManager:", address(bondManager));
        console.log("- Buyback:", address(buyback));
        console.log("- Governance:", address(governance));
        console.log("- AttestationEmitter:", address(attestationEmitter));
        console.log("\\nProtocol Adapters:");
        console.log("- AaveAdapter:", address(aaveAdapter));
        console.log("- WLFAdapter:", address(wlfAdapter));
        console.log("- UniswapAdapter:", address(uniswapAdapter));
        console.log("- AerodromeAdapter:", address(aerodromeAdapter));
        console.log("\\nPhase 1 Features:");
        console.log("- LPStaking:", address(lpStaking));
        console.log("- POLManager:", address(polManager));
        console.log("- KeeperRegistry:", address(keeperRegistry));
        console.log("\\nReady for Phase 1 launch on Base L2!");

        vm.stopBroadcast();
    }
}
