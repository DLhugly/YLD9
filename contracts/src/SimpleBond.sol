// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IAttestationEmitter.sol";

/**
 * @title SimpleBond
 * @notice Ultra-simple USDC bonds with fixed 10% discount and 7-day vesting
 * @dev Single bond type, proceeds go 100% to ETH treasury accumulation
 */
contract SimpleBond is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============
    
    uint256 public constant DISCOUNT_BPS = 1000; // 10% discount
    uint256 public constant VESTING_DAYS = 7;
    uint256 public constant WEEKLY_CAP = 100000e18; // 100K AGN per week
    uint256 public constant WEEK_DURATION = 7 days;

    // ============ Immutables ============
    
    IERC20 public immutable USDC;
    IERC20 public immutable AGN;
    ITreasury public immutable treasury;
    IAttestationEmitter public immutable attestationEmitter;

    // ============ State Variables ============
    
    struct Bond {
        uint256 amount;        // Total AGN amount to vest
        uint256 vestingStart;  // Vesting start timestamp
        uint256 claimed;       // Already claimed amount
    }

    mapping(address => Bond[]) public userBonds;
    
    uint256 public weeklyIssued;     // AGN issued this week
    uint256 public weekStart;        // Current week start timestamp
    uint256 public totalIssued;      // Total AGN ever issued
    
    bool public paused;              // Emergency pause

    // ============ Events ============
    
    event BondPurchased(
        address indexed user,
        uint256 usdcAmount,
        uint256 agnAmount,
        uint256 bondId,
        uint256 timestamp
    );
    
    event BondClaimed(
        address indexed user,
        uint256 bondId,
        uint256 amount,
        uint256 timestamp
    );
    
    event WeeklyCapReset(uint256 newWeekStart, uint256 weeklyIssued);
    event EmergencyPaused(bool paused);

    // ============ Constructor ============
    
    constructor(
        address _usdc,
        address _agn,
        address _treasury,
        address _attestationEmitter
    ) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC address");
        require(_agn != address(0), "Invalid AGN address");
        require(_treasury != address(0), "Invalid treasury address");
        require(_attestationEmitter != address(0), "Invalid attestation emitter");

        USDC = IERC20(_usdc);
        AGN = IERC20(_agn);
        treasury = ITreasury(_treasury);
        attestationEmitter = IAttestationEmitter(_attestationEmitter);
        
        weekStart = block.timestamp;
    }

    // ============ Main Functions ============

    /**
     * @notice Purchase USDC bonds for discounted AGN
     * @param usdcAmount Amount of USDC to deposit
     * @return bondId The ID of the created bond
     */
    function deposit(uint256 usdcAmount) external nonReentrant returns (uint256 bondId) {
        require(!paused, "Bonds paused");
        require(usdcAmount > 0, "Amount must be > 0");

        // Check safety gates
        require(treasury.getRunwayMonths() >= 6, "Runway < 6 months");
        require(treasury.getCoverageRatio() >= 1.2e18, "Coverage ratio < 1.2x");

        // Reset weekly cap if needed
        if (block.timestamp >= weekStart + WEEK_DURATION) {
            emit WeeklyCapReset(block.timestamp, weeklyIssued);
            weekStart = block.timestamp;
            weeklyIssued = 0;
        }

        // Calculate discounted AGN amount
        uint256 agnPrice = treasury.getAGNPrice(); // Price in USDC per AGN (18 decimals)
        uint256 discountedPrice = (agnPrice * (10000 - DISCOUNT_BPS)) / 10000;
        uint256 agnAmount = (usdcAmount * 1e18) / discountedPrice; // Convert USDC (6 decimals) to AGN amount

        // Check weekly cap
        require(weeklyIssued + agnAmount <= WEEKLY_CAP, "Weekly cap exceeded");

        // Transfer USDC to treasury
        USDC.safeTransferFrom(msg.sender, address(treasury), usdcAmount);

        // Create bond
        bondId = userBonds[msg.sender].length;
        userBonds[msg.sender].push(Bond({
            amount: agnAmount,
            vestingStart: block.timestamp,
            claimed: 0
        }));

        // Update state
        weeklyIssued += agnAmount;
        totalIssued += agnAmount;

        // Trigger treasury to process inflow (convert to ETH and execute buybacks)
        treasury.processInflow(usdcAmount);

        // Emit events
        emit BondPurchased(msg.sender, usdcAmount, agnAmount, bondId, block.timestamp);
        
        attestationEmitter.emitBondPurchased(
            msg.sender,
            usdcAmount,
            agnAmount,
            block.timestamp
        );
    }

    /**
     * @notice Claim vested AGN from a bond
     * @param bondId The bond ID to claim from
     * @return claimedAmount Amount of AGN claimed
     */
    function claim(uint256 bondId) external nonReentrant returns (uint256 claimedAmount) {
        require(bondId < userBonds[msg.sender].length, "Invalid bond ID");

        Bond storage bond = userBonds[msg.sender][bondId];
        require(bond.amount > 0, "Bond does not exist");

        claimedAmount = _getClaimableAmount(msg.sender, bondId);
        require(claimedAmount > 0, "Nothing to claim");

        // Update bond state
        bond.claimed += claimedAmount;

        // Transfer AGN to user
        AGN.safeTransfer(msg.sender, claimedAmount);

        // Emit events
        emit BondClaimed(msg.sender, bondId, claimedAmount, block.timestamp);
        
        attestationEmitter.emitBondClaimed(
            msg.sender,
            bondId,
            claimedAmount,
            block.timestamp
        );
    }

    /**
     * @notice Claim from multiple bonds at once
     * @param bondIds Array of bond IDs to claim from
     * @return totalClaimed Total amount of AGN claimed
     */
    function claimMultiple(uint256[] calldata bondIds) external nonReentrant returns (uint256 totalClaimed) {
        for (uint256 i = 0; i < bondIds.length; i++) {
            uint256 bondId = bondIds[i];
            require(bondId < userBonds[msg.sender].length, "Invalid bond ID");

            Bond storage bond = userBonds[msg.sender][bondId];
            if (bond.amount == 0) continue;

            uint256 claimable = _getClaimableAmount(msg.sender, bondId);
            if (claimable == 0) continue;

            bond.claimed += claimable;
            totalClaimed += claimable;

            emit BondClaimed(msg.sender, bondId, claimable, block.timestamp);
        }

        if (totalClaimed > 0) {
            AGN.safeTransfer(msg.sender, totalClaimed);
        }
    }

    // ============ View Functions ============

    /**
     * @notice Get claimable amount for a specific bond
     */
    function getClaimableAmount(address user, uint256 bondId) external view returns (uint256) {
        return _getClaimableAmount(user, bondId);
    }

    /**
     * @notice Get total claimable amount across all user bonds
     */
    function getTotalClaimable(address user) external view returns (uint256 totalClaimable) {
        uint256 bondCount = userBonds[user].length;
        for (uint256 i = 0; i < bondCount; i++) {
            totalClaimable += _getClaimableAmount(user, i);
        }
    }

    /**
     * @notice Get user bond count
     */
    function getUserBondCount(address user) external view returns (uint256) {
        return userBonds[user].length;
    }

    /**
     * @notice Get user bond details
     */
    function getUserBond(address user, uint256 bondId) external view returns (
        uint256 amount,
        uint256 vestingStart,
        uint256 claimed,
        uint256 claimable,
        uint256 vestingEnd
    ) {
        require(bondId < userBonds[user].length, "Invalid bond ID");
        
        Bond storage bond = userBonds[user][bondId];
        amount = bond.amount;
        vestingStart = bond.vestingStart;
        claimed = bond.claimed;
        claimable = _getClaimableAmount(user, bondId);
        vestingEnd = bond.vestingStart + (VESTING_DAYS * 1 days);
    }

    /**
     * @notice Get current week remaining capacity
     */
    function getWeeklyCapRemaining() external view returns (uint256) {
        if (block.timestamp >= weekStart + WEEK_DURATION) {
            return WEEKLY_CAP; // New week, full capacity
        }
        return WEEKLY_CAP - weeklyIssued;
    }

    /**
     * @notice Preview AGN amount for USDC deposit
     */
    function previewDeposit(uint256 usdcAmount) external view returns (uint256 agnAmount) {
        uint256 agnPrice = treasury.getAGNPrice();
        uint256 discountedPrice = (agnPrice * (10000 - DISCOUNT_BPS)) / 10000;
        agnAmount = (usdcAmount * 1e18) / discountedPrice;
    }

    // ============ Internal Functions ============

    function _getClaimableAmount(address user, uint256 bondId) internal view returns (uint256) {
        if (bondId >= userBonds[user].length) return 0;
        
        Bond storage bond = userBonds[user][bondId];
        if (bond.amount == 0) return 0;

        uint256 elapsed = block.timestamp - bond.vestingStart;
        uint256 vestingPeriod = VESTING_DAYS * 1 days;

        uint256 vestedAmount;
        if (elapsed >= vestingPeriod) {
            vestedAmount = bond.amount; // Fully vested
        } else {
            vestedAmount = (bond.amount * elapsed) / vestingPeriod; // Linear vesting
        }

        return vestedAmount - bond.claimed;
    }

    // ============ Admin Functions ============

    /**
     * @notice Emergency pause/unpause bond issuance
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit EmergencyPaused(_paused);
    }

    /**
     * @notice Emergency withdrawal of AGN (only if paused)
     */
    function emergencyWithdraw() external onlyOwner {
        require(paused, "Not paused");
        uint256 balance = AGN.balanceOf(address(this));
        if (balance > 0) {
            AGN.safeTransfer(owner(), balance);
        }
    }
}
