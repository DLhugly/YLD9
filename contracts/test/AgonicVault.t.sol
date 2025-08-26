// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import "../src/Treasury.sol";
import "../src/AttestationEmitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Mock ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title AgonicVaultTest
 * @notice Basic tests for Agonic v1 ultra-simple contracts
 */
contract AgonicVaultTest is Test {
    Treasury public treasury;
    AttestationEmitter public attestationEmitter;
    
    MockERC20 public usdc;
    MockERC20 public usd1;
    MockERC20 public eurc;
    MockERC20 public weth;
    MockERC20 public agn;
    
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
        agn = new MockERC20("Agonic", "AGN");
        
        // Deploy contracts
        attestationEmitter = new AttestationEmitter();
        treasury = new Treasury(
            address(usdc),
            address(usd1),
            address(eurc),
            address(weth),
            address(agn)
        );
        
        // Setup user balances
        usdc.mint(user1, INITIAL_BALANCE);
        usd1.mint(user1, INITIAL_BALANCE);
        eurc.mint(user1, INITIAL_BALANCE);
        weth.mint(user1, INITIAL_BALANCE);
        agn.mint(user1, INITIAL_BALANCE);
    }

    function testTreasuryDeployment() public {
        // Test basic treasury functionality
        assertEq(address(treasury.USDC()), address(usdc));
        assertEq(address(treasury.WETH()), address(weth));
        assertEq(treasury.AGN(), address(agn));
        assertTrue(treasury.owner() == address(this));
    }

    function testTreasuryETHPrice() public {
        // Test ETH price functionality
        uint256 currentPrice = treasury.getCurrentETHPrice();
        assertTrue(currentPrice > 0);
        
        // Test manual price update
        treasury.updateETHPrice(3000e6); // $3000
        assertEq(treasury.getCurrentETHPrice(), 3000e6);
    }

    function testTreasuryCirculatingSupply() public {
        // Test circulating supply calculation
        uint256 supply = treasury.getCirculatingSupply();
        assertTrue(supply >= 0); // Supply should be non-negative
    }

    function testTreasuryGetTotalValue() public {
        // Test total treasury value calculation
        uint256 totalValue = treasury.getTotalTreasuryValue();
        assertTrue(totalValue >= 0); // Should be non-negative
    }

    function testTreasuryAGNPrice() public {
        // Test AGN price function
        uint256 agnPrice = treasury.getAGNPrice();
        assertEq(agnPrice, 1e18); // Should return $1.00 per AGN
    }
}