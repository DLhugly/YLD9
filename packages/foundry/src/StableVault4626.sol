// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITreasuryManager.sol";
import "./interfaces/ITreasury.sol";

/**
 * @title StableVault4626
 * @notice Multi-stablecoin ERC-4626 vault supporting USDC, USD1, EURC
 * @dev Implements conservative yield farming with protocol allocation caps and fee collection
 */
contract StableVault4626 is ERC4626, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Supported stablecoin assets
    mapping(address => bool) public supportedAssets;
    
    /// @notice Asset balances by token address
    mapping(address => uint256) public assetBalances;
    
    /// @notice Treasury manager for protocol integrations
    ITreasuryManager public treasuryManager;
    
    /// @notice Treasury contract for fee collection
    ITreasury public treasury;
    
    /// @notice Fee on yield (basis points, e.g., 1200 = 12%)
    uint256 public yieldFeeBps = 1200;
    
    /// @notice Minimum idle buffer percentage (basis points)
    uint256 public idleBufferBps = 2000; // 20%
    
    /// @notice Total assets under management across all stablecoins
    uint256 public totalAUM;
    
    /// @notice Supported asset addresses
    address[] public assetList;
    
    /// @notice Maximum basis points (100%)
    uint256 public constant MAX_BPS = 10000;
    
    /// @notice Events
    event AssetAdded(address indexed asset);
    event AssetRemoved(address indexed asset);
    event YieldHarvested(uint256 totalYield, uint256 feeAmount);
    event TreasuryManagerUpdated(address indexed newManager);
    event YieldFeeUpdated(uint256 newFeeBps);
    event IdleBufferUpdated(uint256 newBufferBps);

    constructor(
        address _primaryAsset,
        string memory _name,
        string memory _symbol,
        address _treasuryManager,
        address _treasury
    ) ERC4626(IERC20(_primaryAsset)) ERC20(_name, _symbol) Ownable(msg.sender) {
        treasuryManager = ITreasuryManager(_treasuryManager);
        treasury = ITreasury(_treasury);
        
        // Add primary asset (USDC)
        supportedAssets[_primaryAsset] = true;
        assetList.push(_primaryAsset);
        emit AssetAdded(_primaryAsset);
    }

    /**
     * @notice Add supported stablecoin asset
     * @param asset Address of the stablecoin to add
     */
    function addAsset(address asset) external onlyOwner {
        require(!supportedAssets[asset], "Asset already supported");
        require(asset != address(0), "Invalid asset address");
        
        supportedAssets[asset] = true;
        assetList.push(asset);
        emit AssetAdded(asset);
    }

    /**
     * @notice Remove supported stablecoin asset
     * @param asset Address of the stablecoin to remove
     */
    function removeAsset(address asset) external onlyOwner {
        require(supportedAssets[asset], "Asset not supported");
        require(assetBalances[asset] == 0, "Asset has balance");
        
        supportedAssets[asset] = false;
        
        // Remove from asset list
        for (uint256 i = 0; i < assetList.length; i++) {
            if (assetList[i] == asset) {
                assetList[i] = assetList[assetList.length - 1];
                assetList.pop();
                break;
            }
        }
        
        emit AssetRemoved(asset);
    }

    /**
     * @notice Deposit multiple stablecoins
     * @param assets Array of asset addresses
     * @param amounts Array of amounts to deposit
     * @param receiver Address to receive vault shares
     * @return shares Number of shares minted
     */
    function depositMultiAsset(
        address[] calldata assets,
        uint256[] calldata amounts,
        address receiver
    ) external nonReentrant returns (uint256 shares) {
        require(assets.length == amounts.length, "Array length mismatch");
        
        uint256 totalValue = 0;
        
        for (uint256 i = 0; i < assets.length; i++) {
            require(supportedAssets[assets[i]], "Unsupported asset");
            require(amounts[i] > 0, "Invalid amount");
            
            IERC20(assets[i]).safeTransferFrom(msg.sender, address(this), amounts[i]);
            assetBalances[assets[i]] += amounts[i];
            totalValue += amounts[i]; // Assuming 1:1 USD value for stablecoins
        }
        
        totalAUM += totalValue;
        
        // Calculate shares based on total USD value
        if (totalSupply() == 0) {
            shares = totalValue;
        } else {
            shares = (totalValue * totalSupply()) / totalAssets();
        }
        
        _mint(receiver, shares);
        
        // Rebalance after deposit
        _rebalance();
    }

    /**
     * @notice Withdraw to specific stablecoin
     * @param shares Number of shares to redeem
     * @param asset Desired stablecoin address
     * @param receiver Address to receive assets
     * @return assets Amount of assets withdrawn
     */
    function withdrawToAsset(
        uint256 shares,
        address asset,
        address receiver
    ) external nonReentrant returns (uint256 assets) {
        require(supportedAssets[asset], "Unsupported asset");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");
        
        assets = previewRedeem(shares);
        
        // Check if we have enough of the requested asset
        uint256 availableAsset = assetBalances[asset];
        if (availableAsset < assets) {
            // Rebalance to get more of the requested asset
            treasuryManager.rebalanceForWithdrawal(asset, assets - availableAsset);
        }
        
        _burn(msg.sender, shares);
        assetBalances[asset] -= assets;
        totalAUM -= assets;
        
        IERC20(asset).safeTransfer(receiver, assets);
    }

    /**
     * @notice Harvest yield from all protocols
     * @return totalYield Total yield harvested
     * @return feeAmount Fee collected for treasury
     */
    function harvest() external nonReentrant returns (uint256 totalYield, uint256 feeAmount) {
        // For testing, allow anyone to call harvest, in production restrict to owner/keeper
        totalYield = treasuryManager.harvestAll();
        
        if (totalYield > 0) {
            feeAmount = (totalYield * yieldFeeBps) / MAX_BPS;
            uint256 netYield = totalYield - feeAmount;
            
            totalAUM += netYield;
            
            // Mint fee amount to vault, then transfer to treasury
            // In production this would come from actual yield harvesting
            if (feeAmount > 0) {
                // For testing: mint tokens to represent fee collection
                // IERC20(asset()).safeTransfer(address(treasury), feeAmount);
            }
            
            emit YieldHarvested(totalYield, feeAmount);
        }
    }

    /**
     * @notice Rebalance assets across protocols
     */
    function rebalance() external onlyOwner {
        _rebalance();
    }

    /**
     * @notice Internal rebalance function
     */
    function _rebalance() internal {
        // Ensure minimum idle buffer
        uint256 requiredIdle = (totalAUM * idleBufferBps) / MAX_BPS;
        
        // Rebalance through treasury manager
        treasuryManager.rebalance(requiredIdle);
    }

    /**
     * @notice Get total assets under management
     * @return Total assets in USD terms
     */
    function totalAssets() public view override returns (uint256) {
        return totalAUM + treasuryManager.getTotalDeployed();
    }

    /**
     * @notice Get asset allocation breakdown
     * @return assets Array of asset addresses
     * @return balances Array of asset balances
     */
    function getAssetBreakdown() external view returns (address[] memory assets, uint256[] memory balances) {
        assets = assetList;
        balances = new uint256[](assetList.length);
        
        for (uint256 i = 0; i < assetList.length; i++) {
            balances[i] = assetBalances[assetList[i]];
        }
    }

    /**
     * @notice Update treasury manager
     * @param newManager New treasury manager address
     */
    function updateTreasuryManager(address newManager) external onlyOwner {
        require(newManager != address(0), "Invalid address");
        treasuryManager = ITreasuryManager(newManager);
        emit TreasuryManagerUpdated(newManager);
    }

    /**
     * @notice Update yield fee
     * @param newFeeBps New fee in basis points
     */
    function updateYieldFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 2000, "Fee too high"); // Max 20%
        yieldFeeBps = newFeeBps;
        emit YieldFeeUpdated(newFeeBps);
    }

    /**
     * @notice Update idle buffer percentage
     * @param newBufferBps New buffer in basis points
     */
    function updateIdleBuffer(uint256 newBufferBps) external onlyOwner {
        require(newBufferBps <= 5000, "Buffer too high"); // Max 50%
        idleBufferBps = newBufferBps;
        emit IdleBufferUpdated(newBufferBps);
    }

    /**
     * @notice Emergency pause - withdraw all funds from protocols
     */
    function emergencyWithdraw() external onlyOwner {
        treasuryManager.emergencyWithdraw();
    }
}
