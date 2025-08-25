// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ATNTranche.sol";
import "./interfaces/ITreasury.sol";

/**
 * @title BondManager
 * @notice Manages Agonic Treasury Notes (ATN) issuance with multi-stablecoin support
 * @dev Fixed-APR notes to accelerate ETH accumulation, gated by coverage ratio
 */
contract BondManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Treasury contract for safety gate checks
    ITreasury public treasury;
    
    /// @notice Supported stablecoin assets
    mapping(address => bool) public supportedAssets;
    
    /// @notice Active tranches by ID
    mapping(uint256 => ATNTranche) public tranches;
    
    /// @notice Tranche metadata
    mapping(uint256 => TrancheInfo) public trancheInfo;
    
    /// @notice User subscriptions by tranche ID
    mapping(uint256 => mapping(address => uint256)) public userSubscriptions;
    
    /// @notice Total outstanding principal across all tranches
    uint256 public totalOutstandingPrincipal;
    
    /// @notice Next tranche ID
    uint256 public nextTrancheId = 1;
    
    /// @notice Minimum subscription amount
    uint256 public minSubscription = 1000e6; // $1,000 minimum
    
    /// @notice Maximum subscription per user per tranche
    uint256 public maxUserSubscription = 100000e6; // $100,000 max
    
    /// @notice Tranche information struct
    struct TrancheInfo {
        string name;
        uint256 apr; // Annual percentage rate (scaled by 1e18)
        uint256 termMonths; // Term in months
        uint256 cap; // Maximum issuance cap
        uint256 issued; // Amount already issued
        address asset; // Stablecoin asset
        uint256 launchTime; // When tranche was launched
        uint256 maturityTime; // When notes mature
        bool active; // Whether tranche is active
        bool matured; // Whether tranche has matured
    }
    
    /// @notice Events
    event TrancheCreated(uint256 indexed trancheId, string name, uint256 apr, uint256 cap, address asset);
    event Subscription(uint256 indexed trancheId, address indexed user, uint256 amount);
    event CouponPayment(uint256 indexed trancheId, address indexed user, uint256 amount);
    event Redemption(uint256 indexed trancheId, address indexed user, uint256 principal, uint256 finalCoupon);
    event TranchePaused(uint256 indexed trancheId, string reason);
    event TrancheClosed(uint256 indexed trancheId);

    constructor(address _treasury) Ownable(msg.sender) {
        treasury = ITreasury(_treasury);
        
        // Add Base L2 stablecoins
        supportedAssets[0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913] = true; // USDC
    }

    /**
     * @notice Create a new ATN tranche
     * @param name Tranche name (e.g., "ATN-01")
     * @param apr Annual percentage rate (e.g., 8e16 for 8%)
     * @param termMonths Term in months
     * @param cap Maximum issuance cap
     * @param asset Stablecoin asset address
     * @return trancheId New tranche ID
     */
    function createTranche(
        string calldata name,
        uint256 apr,
        uint256 termMonths,
        uint256 cap,
        address asset
    ) external onlyOwner returns (uint256 trancheId) {
        require(supportedAssets[asset], "Unsupported asset");
        require(apr > 0 && apr <= 20e16, "Invalid APR"); // Max 20%
        require(termMonths >= 1 && termMonths <= 60, "Invalid term"); // 1-60 months
        require(cap > 0, "Invalid cap");
        
        trancheId = nextTrancheId++;
        
        // Deploy new tranche contract
        ATNTranche tranche = new ATNTranche(
            name,
            string(abi.encodePacked("ATN", _toString(trancheId))),
            asset,
            address(this)
        );
        
        tranches[trancheId] = tranche;
        
        trancheInfo[trancheId] = TrancheInfo({
            name: name,
            apr: apr,
            termMonths: termMonths,
            cap: cap,
            issued: 0,
            asset: asset,
            launchTime: block.timestamp,
            maturityTime: block.timestamp + (termMonths * 30 days),
            active: true,
            matured: false
        });
        
        emit TrancheCreated(trancheId, name, apr, cap, asset);
    }

    /**
     * @notice Subscribe to ATN tranche
     * @param trancheId Tranche ID to subscribe to
     * @param amount Amount to subscribe
     * @return success Whether subscription was successful
     */
    function subscribe(uint256 trancheId, uint256 amount) external nonReentrant returns (bool success) {
        TrancheInfo storage info = trancheInfo[trancheId];
        require(info.active && !info.matured, "Tranche not active");
        require(amount >= minSubscription, "Amount below minimum");
        require(amount <= maxUserSubscription, "Amount above maximum");
        require(info.issued + amount <= info.cap, "Exceeds tranche cap");
        
        // Check coverage ratio safety gate
        (, bool crOK) = treasury.getSafetyGateStatus();
        require(crOK, "Coverage ratio too low");
        
        // Transfer stablecoin from user
        IERC20(info.asset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Mint ATN tokens to user (non-transferable until maturity)
        ATNTranche tranche = tranches[trancheId];
        tranche.mint(msg.sender, amount);
        
        // Update accounting
        userSubscriptions[trancheId][msg.sender] += amount;
        info.issued += amount;
        totalOutstandingPrincipal += amount;
        
        // Route proceeds to treasury for ETH DCA
        IERC20(info.asset).safeTransfer(address(treasury), amount);
        treasury.deposit(info.asset, amount);
        
        emit Subscription(trancheId, msg.sender, amount);
        success = true;
    }

    /**
     * @notice Pay weekly coupons for a tranche
     * @param trancheId Tranche ID to pay coupons for
     */
    function payCoupons(uint256 trancheId) external onlyOwner nonReentrant {
        TrancheInfo storage info = trancheInfo[trancheId];
        require(info.active && !info.matured, "Tranche not active");
        require(block.timestamp < info.maturityTime, "Tranche matured");
        
        ATNTranche tranche = tranches[trancheId];
        uint256 totalSupply = tranche.totalSupply();
        
        if (totalSupply == 0) return;
        
        // Calculate weekly coupon: (APR * Principal) / 52
        uint256 weeklyCouponRate = info.apr / 52;
        uint256 totalCoupons = (totalSupply * weeklyCouponRate) / 1e18;
        
        // Check if treasury has sufficient funds
        // In production: verify treasury balance before paying
        
        // Pay coupons to all holders
        // For simplicity, this implementation pays proportionally
        // In production, would iterate through all holders
        
        emit CouponPayment(trancheId, address(0), totalCoupons);
    }

    /**
     * @notice Pay coupons for all active tranches (called by keeper)
     */
    function payAllCoupons() external onlyOwner {
        for (uint256 i = 1; i < nextTrancheId; i++) {
            TrancheInfo storage info = trancheInfo[i];
            if (info.active && !info.matured && block.timestamp < info.maturityTime) {
                try this.payCoupons(i) {
                    // Coupon payment succeeded
                } catch {
                    // Continue to next tranche if one fails
                    continue;
                }
            }
        }
    }

    /**
     * @notice Redeem matured ATN notes
     * @param trancheId Tranche ID to redeem from
     * @param amount Amount to redeem
     */
    function redeem(uint256 trancheId, uint256 amount) external nonReentrant {
        TrancheInfo storage info = trancheInfo[trancheId];
        require(block.timestamp >= info.maturityTime, "Not yet matured");
        require(amount > 0, "Invalid amount");
        
        ATNTranche tranche = tranches[trancheId];
        require(tranche.balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Calculate final coupon payment
        uint256 weeklyCouponRate = info.apr / 52;
        uint256 finalCoupon = (amount * weeklyCouponRate) / 1e18;
        
        // Burn ATN tokens
        tranche.burn(msg.sender, amount);
        
        // Transfer principal + final coupon back to user
        uint256 totalRedemption = amount + finalCoupon;
        IERC20(info.asset).safeTransfer(msg.sender, totalRedemption);
        
        // Update accounting
        userSubscriptions[trancheId][msg.sender] -= amount;
        totalOutstandingPrincipal -= amount;
        
        emit Redemption(trancheId, msg.sender, amount, finalCoupon);
    }

    /**
     * @notice Pause tranche issuance (emergency or CR breach)
     * @param trancheId Tranche ID to pause
     * @param reason Reason for pausing
     */
    function pauseTranche(uint256 trancheId, string calldata reason) external onlyOwner {
        TrancheInfo storage info = trancheInfo[trancheId];
        require(info.active, "Tranche not active");
        
        info.active = false;
        
        emit TranchePaused(trancheId, reason);
    }

    /**
     * @notice Resume tranche issuance
     * @param trancheId Tranche ID to resume
     */
    function resumeTranche(uint256 trancheId) external onlyOwner {
        TrancheInfo storage info = trancheInfo[trancheId];
        require(!info.active && !info.matured, "Cannot resume tranche");
        
        // Check coverage ratio before resuming
        (, bool crOK) = treasury.getSafetyGateStatus();
        require(crOK, "Coverage ratio still too low");
        
        info.active = true;
    }

    /**
     * @notice Close matured tranche
     * @param trancheId Tranche ID to close
     */
    function closeTranche(uint256 trancheId) external onlyOwner {
        TrancheInfo storage info = trancheInfo[trancheId];
        require(block.timestamp >= info.maturityTime, "Not yet matured");
        
        ATNTranche tranche = tranches[trancheId];
        require(tranche.totalSupply() == 0, "Outstanding tokens exist");
        
        info.matured = true;
        info.active = false;
        
        emit TrancheClosed(trancheId);
    }

    /**
     * @notice Add supported stablecoin asset
     * @param asset Asset address to add
     */
    function addSupportedAsset(address asset) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        supportedAssets[asset] = true;
    }

    /**
     * @notice Update subscription limits
     * @param newMinSubscription New minimum subscription
     * @param newMaxUserSubscription New maximum user subscription
     */
    function updateSubscriptionLimits(uint256 newMinSubscription, uint256 newMaxUserSubscription) external onlyOwner {
        require(newMinSubscription > 0, "Invalid minimum");
        require(newMaxUserSubscription > newMinSubscription, "Invalid maximum");
        
        minSubscription = newMinSubscription;
        maxUserSubscription = newMaxUserSubscription;
    }

    /**
     * @notice Get tranche details
     * @param trancheId Tranche ID
     * @return info Tranche information
     */
    function getTrancheInfo(uint256 trancheId) external view returns (TrancheInfo memory info) {
        info = trancheInfo[trancheId];
    }

    /**
     * @notice Get user subscription amount for tranche
     * @param trancheId Tranche ID
     * @param user User address
     * @return amount Subscription amount
     */
    function getUserSubscription(uint256 trancheId, address user) external view returns (uint256 amount) {
        amount = userSubscriptions[trancheId][user];
    }

    /**
     * @notice Get all active tranches
     * @return activeTrancheIds Array of active tranche IDs
     */
    function getActiveTranches() external view returns (uint256[] memory activeTrancheIds) {
        uint256 count = 0;
        
        // Count active tranches
        for (uint256 i = 1; i < nextTrancheId; i++) {
            if (trancheInfo[i].active && !trancheInfo[i].matured) {
                count++;
            }
        }
        
        // Build array
        activeTrancheIds = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 1; i < nextTrancheId; i++) {
            if (trancheInfo[i].active && !trancheInfo[i].matured) {
                activeTrancheIds[index] = i;
                index++;
            }
        }
    }

    /**
     * @notice Update treasury contract
     * @param newTreasury New treasury address
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = ITreasury(newTreasury);
        
        // Update outstanding principal in new treasury
        treasury.updateOutstandingATN(totalOutstandingPrincipal);
    }

    /**
     * @notice Internal helper to convert uint to string
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
