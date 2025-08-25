// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/StableVault4626.sol";
import "../src/Treasury.sol";
import "../src/TreasuryManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Mock ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title AgonicVaultTest
 * @notice Comprehensive tests for Agonic v1 contracts
 */
contract AgonicVaultTest is Test {
    StableVault4626 public vault;
    Treasury public treasury;
    TreasuryManager public treasuryManager;
    
    MockERC20 public usdc;
    MockERC20 public usd1;
    MockERC20 public eurc;
    MockERC20 public weth;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    uint256 constant INITIAL_BALANCE = 100000e6; // 100k tokens

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC");
        usd1 = new MockERC20("USD1", "USD1");
        eurc = new MockERC20("Euro Coin", "EURC");
        weth = new MockERC20("Wrapped ETH", "WETH");
        
        // Deploy contracts
        treasuryManager = new TreasuryManager();
        treasury = new Treasury(
            address(usdc),
            address(usd1),
            address(eurc),
            address(weth)
        );
        vault = new StableVault4626(
            address(usdc),
            "Agonic Stable Vault",
            "AGV",
            address(treasuryManager),
            address(treasury)
        );
        
        // Configure contracts
        vault.addAsset(address(usd1));
        vault.addAsset(address(eurc));
        
        treasuryManager.addSupportedAsset(address(usdc));
        treasuryManager.addSupportedAsset(address(usd1));
        treasuryManager.addSupportedAsset(address(eurc));
        
        // Setup user balances
        usdc.mint(user1, INITIAL_BALANCE);
        usd1.mint(user1, INITIAL_BALANCE);
        eurc.mint(user1, INITIAL_BALANCE);
        
        usdc.mint(user2, INITIAL_BALANCE);
        usd1.mint(user2, INITIAL_BALANCE);
        eurc.mint(user2, INITIAL_BALANCE);
        
        // Mint some tokens to treasury for testing
        usdc.mint(address(treasury), INITIAL_BALANCE);
        weth.mint(address(treasury), 100e18); // 100 WETH
    }

    function testVaultDeployment() public {
        assertEq(vault.name(), "Agonic Stable Vault");
        assertEq(vault.symbol(), "AGV");
        assertEq(address(vault.asset()), address(usdc));
        assertTrue(vault.supportedAssets(address(usdc)));
        assertTrue(vault.supportedAssets(address(usd1)));
        assertTrue(vault.supportedAssets(address(eurc)));
    }

    function testSingleAssetDeposit() public {
        uint256 depositAmount = 1000e6;
        
        vm.startPrank(user1);
        usdc.approve(address(vault), depositAmount);
        
        uint256 shares = vault.deposit(depositAmount, user1);
        
        assertEq(shares, depositAmount); // 1:1 for first deposit
        assertEq(vault.balanceOf(user1), shares);
        assertEq(vault.assetBalances(address(usdc)), depositAmount);
        vm.stopPrank();
    }

    function testMultiAssetDeposit() public {
        uint256 usdcAmount = 1000e6;
        uint256 usd1Amount = 500e6;
        uint256 eurcAmount = 300e6;
        
        address[] memory assets = new address[](3);
        assets[0] = address(usdc);
        assets[1] = address(usd1);
        assets[2] = address(eurc);
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = usdcAmount;
        amounts[1] = usd1Amount;
        amounts[2] = eurcAmount;
        
        vm.startPrank(user1);
        usdc.approve(address(vault), usdcAmount);
        usd1.approve(address(vault), usd1Amount);
        eurc.approve(address(vault), eurcAmount);
        
        uint256 shares = vault.depositMultiAsset(assets, amounts, user1);
        uint256 expectedShares = usdcAmount + usd1Amount + eurcAmount; // Assuming 1:1 USD value
        
        assertEq(shares, expectedShares);
        assertEq(vault.assetBalances(address(usdc)), usdcAmount);
        assertEq(vault.assetBalances(address(usd1)), usd1Amount);
        assertEq(vault.assetBalances(address(eurc)), eurcAmount);
        vm.stopPrank();
    }

    function testWithdrawToSpecificAsset() public {
        // First deposit
        uint256 depositAmount = 1000e6;
        
        vm.startPrank(user1);
        usdc.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user1);
        
        // Then withdraw to USDC
        uint256 assetsReceived = vault.withdrawToAsset(shares / 2, address(usdc), user1);
        
        assertEq(assetsReceived, depositAmount / 2);
        assertEq(vault.balanceOf(user1), shares / 2);
        assertEq(usdc.balanceOf(user1), INITIAL_BALANCE - depositAmount + assetsReceived);
        vm.stopPrank();
    }

    function testTreasuryDCA() public {
        // Setup treasury with USDC
        uint256 dcaAmount = 1000e6;
        
        vm.startPrank(address(vault));
        usdc.transfer(address(treasury), dcaAmount);
        treasury.deposit(address(usdc), dcaAmount);
        vm.stopPrank();
        
        // Execute DCA
        uint256 ethPurchased = treasury.weeklyDCA(dcaAmount);
        
        assertTrue(ethPurchased > 0);
        (uint256 liquid, , ) = treasury.getETHBreakdown();
        assertEq(liquid, ethPurchased);
    }

    function testTreasuryFXArbitrage() public {
        uint256 arbAmount = 1000e6;
        
        // Setup treasury with USDC
        vm.startPrank(address(vault));
        usdc.transfer(address(treasury), arbAmount);
        treasury.deposit(address(usdc), arbAmount);
        vm.stopPrank();
        
        // Execute FX arbitrage (this will fail with current implementation due to insufficient opportunity)
        vm.expectRevert("Insufficient arbitrage opportunity");
        treasury.executeFXArbitrage(address(usdc), address(usd1), arbAmount);
    }

    function testTreasuryETHStaking() public {
        // Setup treasury with ETH
        vm.deal(address(treasury), 10 ether);
        treasury.updateETHPrice(3000e6); // $3000 per ETH
        
        uint256 stakeAmount = 2 ether;
        uint256 stakedAmount = treasury.stakeETH(stakeAmount);
        
        assertEq(stakedAmount, stakeAmount);
        (uint256 liquid, uint256 staked, ) = treasury.getETHBreakdown();
        assertEq(staked, stakeAmount);
        assertEq(liquid, 8 ether); // 10 - 2 = 8
    }

    function testSafetyGates() public {
        // Test with insufficient runway
        (bool runwayOK, bool crOK) = treasury.getSafetyGateStatus();
        
        // Should fail runway check initially (no OPEX funds)
        assertFalse(runwayOK);
        assertTrue(crOK); // CR should be OK with no outstanding ATN
        
        // Add sufficient funds for runway
        uint256 sixMonthsOpex = 6 * 50000e6; // 6 months * $50k
        vm.startPrank(address(vault));
        usdc.transfer(address(treasury), sixMonthsOpex);
        treasury.deposit(address(usdc), sixMonthsOpex);
        vm.stopPrank();
        
        (runwayOK, crOK) = treasury.getSafetyGateStatus();
        assertTrue(runwayOK);
        assertTrue(crOK);
    }

    function testVaultYieldFee() public {
        uint256 depositAmount = 1000e6;
        
        // User deposits
        vm.startPrank(user1);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        // Simulate yield generation and harvest
        // Note: This is simplified - in production, yield would come from protocol adapters
        uint256 simulatedYield = 100e6; // $100 yield
        usdc.mint(address(vault), simulatedYield);
        
        (uint256 totalYield, uint256 feeAmount) = vault.harvest();
        
        uint256 expectedFee = (simulatedYield * vault.yieldFeeBps()) / 10000; // 12%
        assertEq(feeAmount, expectedFee);
        assertEq(totalYield, simulatedYield);
    }

    function testTreasuryManagerRebalancing() public {
        uint256 totalAmount = 10000e6;
        treasuryManager.updateTotalAUM(totalAmount);
        
        // Test rebalancing
        treasuryManager.rebalance(2000e6); // 20% idle buffer
        
        // Check that allocations were made (simplified test)
        (string[] memory names, uint256[] memory allocations) = treasuryManager.getCurrentAllocations();
        
        assertTrue(names.length > 0);
        // Aave should get priority allocation
        assertTrue(allocations[0] > 0);
    }

    function testParameterUpdates() public {
        // Test vault parameter updates
        uint256 newFeeBps = 1500; // 15%
        vault.updateYieldFee(newFeeBps);
        assertEq(vault.yieldFeeBps(), newFeeBps);
        
        uint256 newBufferBps = 2500; // 25%
        vault.updateIdleBuffer(newBufferBps);
        assertEq(vault.idleBufferBps(), newBufferBps);
        
        // Test treasury parameter updates
        uint256 newOpex = 60000e6; // $60k
        treasury.updateMonthlyOpex(newOpex);
        assertEq(treasury.monthlyOpex(), newOpex);
        
        uint256 newDCACap = 7500e6; // $7.5k
        treasury.updateWeeklyDCACap(newDCACap);
        assertEq(treasury.weeklyDCACap(), newDCACap);
    }

    function testEmergencyFunctions() public {
        uint256 depositAmount = 1000e6;
        
        // Setup vault with deposits
        vm.startPrank(user1);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        // Test emergency withdraw
        vault.emergencyWithdraw();
        
        // Test treasury emergency withdraw
        treasury.emergencyWithdraw(address(usdc), 100e6);
    }

    function testAccessControl() public {
        // Test that non-owners can't call restricted functions
        vm.startPrank(user1);
        
        vm.expectRevert();
        vault.addAsset(address(0x123));
        
        vm.expectRevert();
        treasury.weeklyDCA(1000e6);
        
        vm.expectRevert();
        treasuryManager.addProtocol("Test", address(0x123), 1000);
        
        vm.stopPrank();
    }

    function testReentrancyProtection() public {
        // Basic test - more sophisticated reentrancy tests would require malicious contracts
        uint256 depositAmount = 1000e6;
        
        vm.startPrank(user1);
        usdc.approve(address(vault), depositAmount);
        
        // This should work normally
        vault.deposit(depositAmount, user1);
        
        vm.stopPrank();
    }
}
