// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AaveAdapter
 * @notice Adapter for Aave v3 lending integration on Base L2
 * @dev Provides yield floor through Aave lending
 */
contract AaveAdapter is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Aave Pool address (Base L2)
    address public constant AAVE_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5; // Base Aave Pool
    
    /// @notice Supported assets and their aTokens
    mapping(address => address) public aTokens;
    
    /// @notice Current deposits by asset
    mapping(address => uint256) public deposits;
    
    /// @notice Total deployed assets
    uint256 public totalDeployed;
    
    /// @notice Events
    event Deposited(address asset, uint256 amount, uint256 totalDeployed);
    event Withdrawn(address asset, uint256 amount, uint256 totalDeployed);
    event YieldHarvested(uint256 totalYield);

    constructor() Ownable(msg.sender) {
        // Initialize Base L2 aToken mappings
        // These would be the actual aToken addresses on Base
        aTokens[0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913] = address(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB); // USDC -> aUSDC
    }

    /**
     * @notice Deposit assets to Aave
     * @param asset Asset to deposit
     * @param amount Amount to deposit
     * @return actualDeposited Actual amount deposited
     */
    function deposit(address asset, uint256 amount) external onlyOwner returns (uint256 actualDeposited) {
        require(aTokens[asset] != address(0), "Asset not supported");
        require(amount > 0, "Invalid amount");
        
        // Transfer asset from caller
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        // For testing: simulate Aave deposit
        // In production: IAavePool(AAVE_POOL).supply(asset, amount, address(this), 0);
        
        deposits[asset] += amount;
        totalDeployed += amount;
        actualDeposited = amount;
        
        emit Deposited(asset, amount, totalDeployed);
    }

    /**
     * @notice Withdraw assets from Aave
     * @param asset Asset to withdraw
     * @param amount Amount to withdraw (use type(uint256).max for all)
     * @return actualWithdrawn Actual amount withdrawn
     */
    function withdraw(address asset, uint256 amount) external onlyOwner returns (uint256 actualWithdrawn) {
        require(aTokens[asset] != address(0), "Asset not supported");
        require(deposits[asset] > 0, "No deposits");
        
        actualWithdrawn = amount == type(uint256).max ? deposits[asset] : amount;
        actualWithdrawn = actualWithdrawn > deposits[asset] ? deposits[asset] : actualWithdrawn;
        
        // For testing: simulate Aave withdrawal
        // In production: IAavePool(AAVE_POOL).withdraw(asset, actualWithdrawn, address(this));
        
        deposits[asset] -= actualWithdrawn;
        totalDeployed -= actualWithdrawn;
        
        // Transfer back to caller
        IERC20(asset).safeTransfer(msg.sender, actualWithdrawn);
        
        emit Withdrawn(asset, actualWithdrawn, totalDeployed);
    }

    /**
     * @notice Harvest yield from Aave
     * @return totalYield Total yield harvested
     */
    function harvest() external onlyOwner returns (uint256 totalYield) {
        // Simplified yield calculation: 3% APR
        totalYield = (totalDeployed * 3) / 100 / 52; // Weekly yield
        
        if (totalYield > 0) {
            // In production: claim aToken rewards and calculate actual yield
            // For testing: mint yield to this contract
            
            emit YieldHarvested(totalYield);
        }
    }

    /**
     * @notice Get current APY for an asset
     * @param asset Asset address
     * @return apy Current APY (scaled by 1e18)
     */
    function getCurrentAPY(address asset) external view returns (uint256 apy) {
        if (aTokens[asset] != address(0)) {
            // Simplified: return 3% APY
            apy = 3e16; // 3% = 0.03 * 1e18
        }
    }

    /**
     * @notice Get total balance for an asset (principal + yield)
     * @param asset Asset address
     * @return balance Total balance
     */
    function getBalance(address asset) external view returns (uint256 balance) {
        // In production: return aToken balance
        // For testing: return deposits (no accrued yield tracking)
        balance = deposits[asset];
    }

    /**
     * @notice Get total deployed across all assets
     * @return Total deployed amount
     */
    function getTotalDeployed() external view returns (uint256) {
        return totalDeployed;
    }

    /**
     * @notice Emergency withdraw all assets
     */
    function emergencyWithdraw() external onlyOwner {
        // Withdraw all assets back to treasury manager
        // Implementation would iterate through all supported assets
        totalDeployed = 0;
    }

    /**
     * @notice Add supported asset
     * @param asset Asset address
     * @param aToken Corresponding aToken address
     */
    function addSupportedAsset(address asset, address aToken) external onlyOwner {
        require(asset != address(0) && aToken != address(0), "Invalid addresses");
        aTokens[asset] = aToken;
    }
}
