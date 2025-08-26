// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/Treasury.sol";
import "../src/SimpleBond.sol";
import "../src/StakingVault.sol";
import "../src/Buyback.sol";
import "../src/AttestationEmitter.sol";
import "../src/adapters/AaveAdapter.sol";
import "../src/adapters/LidoAdapter.sol";

/**
 * @title DeployAgonic
 * @notice Deployment script for Agonic v1 Ultra-Simple Treasury Protocol
 */
contract DeployAgonic is Script {
    // Base L2 addresses
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC
    address constant USD1 = address(0x1); // Placeholder for USD1
    address constant EURC = address(0x2); // Placeholder for EURC  
    address constant WETH = 0x4200000000000000000000000000000000000006; // Base WETH
    address constant AGN_TOKEN = address(0x4); // Mock AGN token address

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Agonic v1 Ultra-Simple Treasury Protocol to Base L2...");
        console.log("Deployer:", vm.addr(deployerPrivateKey));

        // 1. Deploy AttestationEmitter
        console.log("Deploying AttestationEmitter...");
        AttestationEmitter attestationEmitter = new AttestationEmitter();
        console.log("AttestationEmitter deployed at:", address(attestationEmitter));

        // 2. Deploy Treasury
        console.log("Deploying Treasury...");
        Treasury treasury = new Treasury(USDC, USD1, EURC, WETH, AGN_TOKEN);
        console.log("Treasury deployed at:", address(treasury));

        // 3. Deploy Buyback contract
        console.log("Deploying Buyback...");
        Buyback buyback = new Buyback(
            AGN_TOKEN,
            USDC,
            address(treasury),
            address(0x5) // Mock AGN/USDC pool address - will be updated after pool creation
        );
        console.log("Buyback deployed at:", address(buyback));

        // 4. Deploy AaveAdapter
        console.log("Deploying AaveAdapter...");
        AaveAdapter aaveAdapter = new AaveAdapter();
        console.log("AaveAdapter deployed at:", address(aaveAdapter));

        // 5. Deploy LidoAdapter
        console.log("Deploying LidoAdapter...");
        LidoAdapter lidoAdapter = new LidoAdapter();
        console.log("LidoAdapter deployed at:", address(lidoAdapter));

        // 6. Deploy StakingVault
        console.log("Deploying StakingVault...");
        StakingVault stakingVault = new StakingVault(
            USDC,
            WETH,
            AGN_TOKEN,
            address(treasury),
            address(attestationEmitter),
            address(aaveAdapter),
            payable(address(lidoAdapter))
        );
        console.log("StakingVault deployed at:", address(stakingVault));

        // 7. Deploy SimpleBond
        console.log("Deploying SimpleBond...");
        SimpleBond simpleBond = new SimpleBond(
            USDC,
            AGN_TOKEN,
            address(treasury),
            address(attestationEmitter)
        );
        console.log("SimpleBond deployed at:", address(simpleBond));

        // 8. Configure contracts
        console.log("Configuring contracts...");
        
        // Set buyback contract in treasury
        treasury.setBuyback(address(buyback));
        
        // Set attestation emitter in treasury
        treasury.setAttestationEmitter(address(attestationEmitter));
        
        // Note: AaveAdapter configuration would need to be done separately
        
        console.log("=== Deployment Summary ===");
        console.log("Treasury:", address(treasury));
        console.log("SimpleBond:", address(simpleBond));
        console.log("StakingVault:", address(stakingVault));
        console.log("Buyback:", address(buyback));
        console.log("AttestationEmitter:", address(attestationEmitter));
        console.log("AaveAdapter:", address(aaveAdapter));
        console.log("LidoAdapter:", address(lidoAdapter));

        vm.stopBroadcast();
    }
}