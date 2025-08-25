// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/StableVault4626.sol";
import "../src/Treasury.sol";
import "../src/TreasuryManager.sol";
import "../src/BondManager.sol";
import "../src/Buyback.sol";
import "../src/Gov.sol";
import "../src/adapters/AaveAdapter.sol";

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

        // 8. Deploy Aave Adapter
        console.log("Deploying AaveAdapter...");
        AaveAdapter aaveAdapter = new AaveAdapter();
        console.log("AaveAdapter deployed at:", address(aaveAdapter));

        // 9. Configure contracts
        console.log("Configuring contracts...");
        
        // Add supported assets to vault
        vault.addAsset(USD1);
        vault.addAsset(EURC);
        
        // Add supported assets to treasury manager
        treasuryManager.addSupportedAsset(USDC);
        treasuryManager.addSupportedAsset(USD1);
        treasuryManager.addSupportedAsset(EURC);

        // Update treasury manager with Aave adapter
        treasuryManager.addProtocol("Aave", address(aaveAdapter), 6000); // 60% limit

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

        console.log("Agonic v1 deployment completed!");
        console.log("Contracts:");
        console.log("- Vault:", address(vault));
        console.log("- Treasury:", address(treasury));
        console.log("- TreasuryManager:", address(treasuryManager));
        console.log("- BondManager:", address(bondManager));
        console.log("- Buyback:", address(buyback));
        console.log("- Governance:", address(governance));
        console.log("- AaveAdapter:", address(aaveAdapter));

        vm.stopBroadcast();
    }
}
