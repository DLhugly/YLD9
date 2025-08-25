// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WLFAdapter
 * @notice Adapter for World Liberty Financial vault integration
 * @dev Handles deposits/withdrawals to WLF vaults for yield generation
 */
contract WLFAdapter is Ownable {
    using SafeERC20 for IERC20;

    /// @notice TreasuryManager contract address
    address public treasuryManager;

    /// @notice WLF vault contracts by asset
    mapping(address => address) public wlfVaults;

    /// @notice Supported assets
    mapping(address => bool) public supportedAssets;

    /// @notice Current deposits by asset
    mapping(address => uint256) public currentDeposits;

    /// @notice Events
    event Deposited(address indexed asset, uint256 amount, address indexed vault);
    event Withdrawn(address indexed asset, uint256 amount, address indexed vault);
    event VaultUpdated(address indexed asset, address indexed vault);
    event YieldClaimed(address indexed asset, uint256 amount);

    constructor(address _treasuryManager) Ownable(msg.sender) {
        require(_treasuryManager != address(0), "Invalid treasury manager");
        treasuryManager = _treasuryManager;
    }

    /**
     * @notice Deposit assets to WLF vault
     * @param asset Asset to deposit
     * @param amount Amount to deposit
     * @return actualDeposited Actual amount deposited
     */
    function deposit(address asset, uint256 amount) external returns (uint256 actualDeposited) {
        require(msg.sender == treasuryManager, "Only treasury manager");
        require(supportedAssets[asset], "Asset not supported");
        require(amount > 0, "Invalid amount");

        address vault = wlfVaults[asset];
        require(vault != address(0), "No vault configured");

        // Transfer assets from treasury manager
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Mock WLF vault deposit - in production integrate with actual WLF contracts
        actualDeposited = _mockWLFDeposit(asset, amount, vault);

        currentDeposits[asset] += actualDeposited;

        emit Deposited(asset, actualDeposited, vault);
    }

    /**
     * @notice Withdraw assets from WLF vault
     * @param asset Asset to withdraw
     * @param amount Amount to withdraw
     * @return actualWithdrawn Actual amount withdrawn
     */
    function withdraw(address asset, uint256 amount) external returns (uint256 actualWithdrawn) {
        require(msg.sender == treasuryManager, "Only treasury manager");
        require(supportedAssets[asset], "Asset not supported");
        require(amount > 0, "Invalid amount");
        require(currentDeposits[asset] >= amount, "Insufficient deposits");

        address vault = wlfVaults[asset];
        require(vault != address(0), "No vault configured");

        // Mock WLF vault withdrawal - in production integrate with actual WLF contracts
        actualWithdrawn = _mockWLFWithdraw(asset, amount, vault);

        currentDeposits[asset] -= actualWithdrawn;

        // Transfer withdrawn assets back to treasury manager
        IERC20(asset).safeTransfer(treasuryManager, actualWithdrawn);

        emit Withdrawn(asset, actualWithdrawn, vault);
    }

    /**
     * @notice Claim yield from WLF vault
     * @param asset Asset to claim yield for
     * @return yieldAmount Yield claimed
     */
    function claimYield(address asset) external returns (uint256 yieldAmount) {
        require(msg.sender == treasuryManager, "Only treasury manager");
        require(supportedAssets[asset], "Asset not supported");

        address vault = wlfVaults[asset];
        require(vault != address(0), "No vault configured");

        // Mock yield claiming - in production integrate with actual WLF contracts
        yieldAmount = _mockWLFClaimYield(asset, vault);

        if (yieldAmount > 0) {
            // Transfer yield back to treasury manager
            IERC20(asset).safeTransfer(treasuryManager, yieldAmount);
            emit YieldClaimed(asset, yieldAmount);
        }
    }

    /**
     * @notice Get current APY for asset
     * @param asset Asset to get APY for
     * @return apy Current APY (scaled by 1e18)
     */
    function getCurrentAPY(address asset) external view returns (uint256 apy) {
        require(supportedAssets[asset], "Asset not supported");
        
        // Mock APY calculation - in production query actual WLF vault
        apy = _mockWLFGetAPY(asset);
    }

    /**
     * @notice Get total value locked for asset
     * @param asset Asset to get TVL for
     * @return tvl Total value locked
     */
    function getTVL(address asset) external view returns (uint256 tvl) {
        require(supportedAssets[asset], "Asset not supported");
        tvl = currentDeposits[asset];
    }

    /**
     * @notice Get available yield for asset
     * @param asset Asset to check yield for
     * @return availableYield Available yield amount
     */
    function getAvailableYield(address asset) external view returns (uint256 availableYield) {
        require(supportedAssets[asset], "Asset not supported");
        
        // Mock available yield calculation - in production query actual WLF vault
        availableYield = _mockWLFGetAvailableYield(asset);
    }

    /**
     * @notice Set WLF vault for asset
     * @param asset Asset address
     * @param vault WLF vault address
     */
    function setWLFVault(address asset, address vault) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        require(vault != address(0), "Invalid vault");
        
        wlfVaults[asset] = vault;
        supportedAssets[asset] = true;
        
        // Approve vault to spend tokens
        IERC20(asset).approve(vault, type(uint256).max);
        
        emit VaultUpdated(asset, vault);
    }

    /**
     * @notice Update treasury manager
     * @param newTreasuryManager New treasury manager address
     */
    function updateTreasuryManager(address newTreasuryManager) external onlyOwner {
        require(newTreasuryManager != address(0), "Invalid treasury manager");
        treasuryManager = newTreasuryManager;
    }

    /**
     * @notice Emergency withdraw all funds
     * @param asset Asset to emergency withdraw
     */
    function emergencyWithdraw(address asset) external onlyOwner {
        require(supportedAssets[asset], "Asset not supported");
        
        uint256 balance = currentDeposits[asset];
        if (balance > 0) {
            address vault = wlfVaults[asset];
            
            // Mock emergency withdrawal - in production use actual WLF emergency functions
            uint256 withdrawn = _mockWLFEmergencyWithdraw(asset, vault);
            
            currentDeposits[asset] = 0;
            
            // Transfer to owner for manual handling
            IERC20(asset).safeTransfer(owner(), withdrawn);
            
            emit Withdrawn(asset, withdrawn, vault);
        }
    }

    // Mock functions for WLF integration - replace with actual WLF contract calls

    /**
     * @notice Mock WLF deposit function
     */
    function _mockWLFDeposit(address asset, uint256 amount, address vault) internal pure returns (uint256) {
        // Mock: assume 1:1 deposit ratio with 0.1% deposit fee
        return (amount * 999) / 1000;
    }

    /**
     * @notice Mock WLF withdraw function
     */
    function _mockWLFWithdraw(address asset, uint256 amount, address vault) internal pure returns (uint256) {
        // Mock: assume 1:1 withdrawal ratio with 0.2% withdrawal fee
        return (amount * 998) / 1000;
    }

    /**
     * @notice Mock WLF yield claiming
     */
    function _mockWLFClaimYield(address asset, address vault) internal view returns (uint256) {
        // Mock: calculate yield based on time and current deposits
        uint256 deposits = currentDeposits[asset];
        if (deposits == 0) return 0;
        
        // Mock 5% APY, calculated as simple interest for demonstration
        uint256 timeElapsed = block.timestamp % (365 days);
        return (deposits * 5 * timeElapsed) / (100 * 365 days);
    }

    /**
     * @notice Mock WLF APY getter
     */
    function _mockWLFGetAPY(address asset) internal pure returns (uint256) {
        // Mock: return 5% APY (5e16)
        return 5e16;
    }

    /**
     * @notice Mock available yield calculation
     */
    function _mockWLFGetAvailableYield(address asset) internal view returns (uint256) {
        // Mock: same as claim yield calculation
        uint256 deposits = currentDeposits[asset];
        if (deposits == 0) return 0;
        
        uint256 timeElapsed = block.timestamp % (365 days);
        return (deposits * 5 * timeElapsed) / (100 * 365 days);
    }

    /**
     * @notice Mock emergency withdrawal
     */
    function _mockWLFEmergencyWithdraw(address asset, address vault) internal view returns (uint256) {
        // Mock: return current deposits minus 1% emergency fee
        return (currentDeposits[asset] * 99) / 100;
    }

    /**
     * @notice Check if adapter is healthy
     * @param asset Asset to check
     * @return healthy Whether adapter is functioning properly
     */
    function isHealthy(address asset) external view returns (bool healthy) {
        if (!supportedAssets[asset]) return false;
        if (wlfVaults[asset] == address(0)) return false;
        
        // Mock health check - in production verify WLF vault is operational
        healthy = true;
    }

    /**
     * @notice Get adapter information
     * @param asset Asset to get info for
     * @return info Adapter information struct
     */
    function getAdapterInfo(address asset) external view returns (AdapterInfo memory info) {
        info = AdapterInfo({
            name: "World Liberty Financial",
            version: "1.0.0",
            asset: asset,
            vault: wlfVaults[asset],
            tvl: currentDeposits[asset],
            apy: supportedAssets[asset] ? _mockWLFGetAPY(asset) : 0,
            isActive: supportedAssets[asset],
            lastUpdate: block.timestamp
        });
    }

    /**
     * @notice Adapter information struct
     */
    struct AdapterInfo {
        string name;
        string version;
        address asset;
        address vault;
        uint256 tvl;
        uint256 apy;
        bool isActive;
        uint256 lastUpdate;
    }
}
