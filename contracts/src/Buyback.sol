// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITreasury.sol";

/**
 * @title Buyback
 * @notice AGN token buyback mechanism with TWAP execution and safety gates
 * @dev Implements weekly buybacks with 50/50 burn/treasury split and LP governance integration
 */
contract Buyback is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice AGN token contract
    IERC20 public immutable AGN;
    
    /// @notice Treasury contract for safety gate checks
    ITreasury public treasury;
    
    /// @notice USDC token for buyback funding
    IERC20 public immutable USDC;
    
    /// @notice DEX router for TWAP execution (Uniswap V3 or Aerodrome)
    address public dexRouter;
    
    /// @notice Buyback pool balance (40% of net yield)
    uint256 public buybackPool;
    
    /// @notice Minimum liquidity threshold for buybacks
    uint256 public minLiquidityThreshold = 50000e6; // $50k minimum pool depth
    
    /// @notice Maximum volume cap (% of 30-day DEX volume)
    uint256 public maxVolumeCap = 1000; // 10% in basis points
    
    /// @notice Weekly buyback frequency
    uint256 public buybackFrequency = 7 days;
    
    /// @notice Last buyback timestamp
    uint256 public lastBuybackTime;
    
    /// @notice TWAP execution parameters
    uint256 public twapDuration = 1 hours; // Execute over 1 hour
    uint256 public twapSlippage = 300; // 3% max slippage
    
    /// @notice Buyback split: 50% burn, 50% treasury
    uint256 public constant BURN_PERCENTAGE = 5000; // 50%
    uint256 public constant TREASURY_PERCENTAGE = 5000; // 50%
    uint256 public constant MAX_BPS = 10000;
    
    /// @notice LP stakers who can vote on buyback parameters
    mapping(address => uint256) public lpStakerWeights;
    mapping(address => bool) public isLPStaker;
    
    /// @notice Buyback execution tracking
    struct BuybackExecution {
        uint256 timestamp;
        uint256 usdcSpent;
        uint256 agnBought;
        uint256 agnBurned;
        uint256 agnToTreasury;
        uint256 avgPrice;
        bool safetyGatesOK;
    }
    
    /// @notice Historical buyback executions
    BuybackExecution[] public buybackHistory;
    
    /// @notice Total statistics
    uint256 public totalUSDCSpent;
    uint256 public totalAGNBought;
    uint256 public totalAGNBurned;
    uint256 public totalAGNToTreasury;
    
    /// @notice Events
    event BuybackPoolFunded(uint256 amount);
    event BuybackExecuted(uint256 usdcSpent, uint256 agnBought, uint256 agnBurned, uint256 agnToTreasury);
    event BuybackSkipped(string reason);
    event ParametersUpdated(string parameter, uint256 value);
    event LPStakerAdded(address indexed staker, uint256 weight);
    event LPStakerRemoved(address indexed staker);

    constructor(
        address _agn,
        address _usdc,
        address _treasury,
        address _dexRouter
    ) Ownable(msg.sender) {
        AGN = IERC20(_agn);
        USDC = IERC20(_usdc);
        treasury = ITreasury(_treasury);
        dexRouter = _dexRouter;
        lastBuybackTime = block.timestamp;
    }

    /**
     * @notice Fund buyback pool (called by Treasury with 40% of net yield)
     * @param amount USDC amount to add to buyback pool
     */
    function fundBuybackPool(uint256 amount) external {
        require(msg.sender == address(treasury) || msg.sender == owner(), "Unauthorized");
        require(amount > 0, "Invalid amount");
        
        USDC.safeTransferFrom(msg.sender, address(this), amount);
        buybackPool += amount;
        
        emit BuybackPoolFunded(amount);
    }

    /**
     * @notice Execute weekly buyback with HARD safety gate enforcement
     * @dev Permissionless but strictly gated by on-chain checks
     */
    function executeBuyback() external nonReentrant {
        // Check timing
        require(block.timestamp >= lastBuybackTime + buybackFrequency, "Too early for buyback");
        require(buybackPool > 0, "No funds in buyback pool");
        
        // HARD SAFETY GATE 1: Runway must be >= 6 months
        (bool runwayOK, bool crOK) = treasury.getSafetyGateStatus();
        require(runwayOK, "SAFETY GATE: Runway < 6 months");
        
        // HARD SAFETY GATE 2: Coverage Ratio must be >= 1.2x
        require(crOK, "SAFETY GATE: Coverage Ratio < 1.2x");
        
        // HARD SAFETY GATE 3: Pool liquidity must be >= $50K
        uint256 poolLiquidity = _getPoolLiquidity();
        require(poolLiquidity >= minLiquidityThreshold, "SAFETY GATE: Pool liquidity < $50K");
        
        // HARD SAFETY GATE 4: Volume cap check (≤10% of 30d volume)
        uint256 volumeLimit = _get30DayVolumeLimit();
        uint256 buybackAmount = buybackPool > volumeLimit ? volumeLimit : buybackPool;
        require(buybackAmount > 0, "Volume limit prevents buyback");
        
        // Execute TWAP buyback with the safe amount
        uint256 agnBought = _executeTWAPBuyback(buybackAmount);
        require(agnBought > 0, "Buyback execution failed");
        
        // Split AGN: 50% burn, 50% to treasury
        uint256 agnToBurn = (agnBought * BURN_PERCENTAGE) / MAX_BPS;
        uint256 agnToTreasury = agnBought - agnToBurn;
        
        // Burn AGN tokens (send to burn address)
        AGN.transfer(address(0xdead), agnToBurn);
        
        // Send AGN to treasury
        AGN.safeTransfer(address(treasury), agnToTreasury);
        
        // Update statistics
        totalUSDCSpent += buybackAmount;
        totalAGNBought += agnBought;
        totalAGNBurned += agnToBurn;
        totalAGNToTreasury += agnToTreasury;
        
        // Record execution
        buybackHistory.push(BuybackExecution({
            timestamp: block.timestamp,
            usdcSpent: buybackAmount,
            agnBought: agnBought,
            agnBurned: agnToBurn,
            agnToTreasury: agnToTreasury,
            avgPrice: buybackAmount * 1e18 / agnBought,
            safetyGatesOK: true
        }));
        
        // Update buyback pool and timestamp
        buybackPool -= buybackAmount;
        lastBuybackTime = block.timestamp;
        
        emit BuybackExecuted(buybackAmount, agnBought, agnToBurn, agnToTreasury);
    }
    
    /**
     * @notice Get current safety gate status (view function for UI/keepers)
     * @return canExecute Whether all gates are green
     * @return runwayOK Whether runway >= 6 months
     * @return crOK Whether CR >= 1.2x
     * @return liquidityOK Whether pool liquidity >= $50K
     * @return volumeOK Whether within 30d volume limits
     */
    function getSafetyGateStatus() external view returns (
        bool canExecute,
        bool runwayOK,
        bool crOK,
        bool liquidityOK,
        bool volumeOK
    ) {
        (runwayOK, crOK) = treasury.getSafetyGateStatus();
        liquidityOK = _getPoolLiquidity() >= minLiquidityThreshold;
        volumeOK = buybackPool <= _get30DayVolumeLimit();
        canExecute = runwayOK && crOK && liquidityOK && volumeOK && 
                    block.timestamp >= lastBuybackTime + buybackFrequency &&
                    buybackPool > 0;
    }

    /**
     * @notice Execute TWAP buyback over specified duration
     * @param usdcAmount USDC amount to spend
     * @return agnBought Total AGN tokens acquired
     */
    function _executeTWAPBuyback(uint256 usdcAmount) internal returns (uint256 agnBought) {
        // Simplified TWAP implementation
        // In production: integrate with actual DEX router for time-weighted execution
        
        // For now, simulate single large purchase with slippage protection
        uint256 minAGNOut = _calculateMinAGNOut(usdcAmount);
        
        // Mock DEX swap - in production use actual router
        agnBought = _mockDEXSwap(usdcAmount, minAGNOut);
    }

    /**
     * @notice Mock DEX swap for testing
     * @param usdcIn USDC input amount
     * @param minAGNOut Minimum AGN output
     * @return agnOut AGN tokens received
     */
    function _mockDEXSwap(uint256 usdcIn, uint256 minAGNOut) internal pure returns (uint256 agnOut) {
        // Mock: assume 1 USDC = 1.2 AGN (price will vary)
        agnOut = (usdcIn * 12) / 10; // 1.2 AGN per USDC
        require(agnOut >= minAGNOut, "Insufficient output");
    }

    /**
     * @notice Calculate minimum AGN output with slippage protection
     * @param usdcAmount USDC input amount
     * @return minAGNOut Minimum AGN output
     */
    function _calculateMinAGNOut(uint256 usdcAmount) internal view returns (uint256 minAGNOut) {
        // Get current AGN price from DEX
        uint256 currentPrice = _getCurrentAGNPrice();
        
        // Calculate expected output
        uint256 expectedAGN = (usdcAmount * 1e18) / currentPrice;
        
        // Apply slippage tolerance
        minAGNOut = (expectedAGN * (MAX_BPS - twapSlippage)) / MAX_BPS;
    }

    /**
     * @notice Get current AGN price from DEX
     * @return price AGN price in USDC (scaled by 1e18)
     */
    function _getCurrentAGNPrice() internal pure returns (uint256 price) {
        // Mock price - in production query actual DEX
        price = 0.83e18; // $0.83 per AGN
    }

    /**
     * @notice Get current pool liquidity from DEX
     * @return liquidity Current pool liquidity in USDC
     */
    function _getPoolLiquidity() internal view returns (uint256 liquidity) {
        // In production: query actual DEX pool reserves
        // For Aerodrome/Uniswap V3, get reserve amounts
        // Mock implementation for testing
        liquidity = 100000e6; // Mock $100K liquidity
    }
    
    /**
     * @notice Calculate 30-day volume limit (10% of rolling volume)
     * @return limit Maximum buyback amount based on volume
     */
    function _get30DayVolumeLimit() internal view returns (uint256 limit) {
        // In production: track 30-day rolling volume via oracle or subgraph
        // Apply maxVolumeCap percentage (default 10%)
        uint256 thirtyDayVolume = 1000000e6; // Mock $1M 30-day volume
        limit = (thirtyDayVolume * maxVolumeCap) / MAX_BPS;
    }
    
    /**
     * @notice Check if liquidity threshold is met (legacy function for compatibility)
     * @return sufficient Whether liquidity is sufficient
     */
    function _checkLiquidityThreshold() internal view returns (bool sufficient) {
        sufficient = _getPoolLiquidity() >= minLiquidityThreshold;
    }

    /**
     * @notice Burn AGN tokens
     * @param amount Amount to burn
     */
    function _burnAGN(uint256 amount) internal {
        // In production: call AGN.burn(amount) or send to dead address
        // For mock: transfer to dead address
        AGN.safeTransfer(address(0x000000000000000000000000000000000000dEaD), amount);
    }

    /**
     * @notice Add LP staker with voting weight
     * @param staker LP staker address
     * @param weight Voting weight
     */
    function addLPStaker(address staker, uint256 weight) external onlyOwner {
        require(staker != address(0), "Invalid staker");
        require(weight > 0, "Invalid weight");
        
        lpStakerWeights[staker] = weight;
        isLPStaker[staker] = true;
        
        emit LPStakerAdded(staker, weight);
    }

    /**
     * @notice Remove LP staker
     * @param staker LP staker address
     */
    function removeLPStaker(address staker) external onlyOwner {
        require(isLPStaker[staker], "Not an LP staker");
        
        lpStakerWeights[staker] = 0;
        isLPStaker[staker] = false;
        
        emit LPStakerRemoved(staker);
    }

    /**
     * @notice Update buyback parameters (governance)
     * @param parameter Parameter name
     * @param value New value
     */
    function updateParameter(string calldata parameter, uint256 value) external onlyOwner {
        bytes32 paramHash = keccak256(bytes(parameter));
        
        if (paramHash == keccak256(bytes("minLiquidityThreshold"))) {
            require(value > 0, "Invalid threshold");
            minLiquidityThreshold = value;
        } else if (paramHash == keccak256(bytes("maxVolumeCap"))) {
            require(value <= 2000, "Cap too high"); // Max 20%
            maxVolumeCap = value;
        } else if (paramHash == keccak256(bytes("twapDuration"))) {
            require(value >= 10 minutes && value <= 4 hours, "Invalid duration");
            twapDuration = value;
        } else if (paramHash == keccak256(bytes("twapSlippage"))) {
            require(value <= 1000, "Slippage too high"); // Max 10%
            twapSlippage = value;
        } else {
            revert("Unknown parameter");
        }
        
        emit ParametersUpdated(parameter, value);
    }

    /**
     * @notice Get buyback statistics
     * @return stats Buyback statistics struct
     */
    function getBuybackStats() external view returns (BuybackStats memory stats) {
        stats = BuybackStats({
            totalExecutions: buybackHistory.length,
            totalUSDCSpent: totalUSDCSpent,
            totalAGNBought: totalAGNBought,
            totalAGNBurned: totalAGNBurned,
            totalAGNToTreasury: totalAGNToTreasury,
            currentPool: buybackPool,
            nextBuybackTime: lastBuybackTime + buybackFrequency,
            canExecute: _canExecuteBuyback()
        });
    }

    /**
     * @notice Check if buyback can be executed
     * @return canExecute Whether buyback can be executed
     */
    function _canExecuteBuyback() internal view returns (bool canExecute) {
        (bool runwayOK, bool crOK) = treasury.getSafetyGateStatus();
        canExecute = block.timestamp >= lastBuybackTime + buybackFrequency &&
                    runwayOK &&
                    crOK &&
                    buybackPool > 0 &&
                    _checkLiquidityThreshold();
    }

    /**
     * @notice Get recent buyback history
     * @param count Number of recent executions to return
     * @return executions Array of recent buyback executions
     */
    function getRecentBuybacks(uint256 count) external view returns (BuybackExecution[] memory executions) {
        uint256 historyLength = buybackHistory.length;
        uint256 returnCount = count > historyLength ? historyLength : count;
        
        executions = new BuybackExecution[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            executions[i] = buybackHistory[historyLength - 1 - i];
        }
    }

    /**
     * @notice Buyback statistics struct
     */
    struct BuybackStats {
        uint256 totalExecutions;
        uint256 totalUSDCSpent;
        uint256 totalAGNBought;
        uint256 totalAGNBurned;
        uint256 totalAGNToTreasury;
        uint256 currentPool;
        uint256 nextBuybackTime;
        bool canExecute;
    }

    /**
     * @notice Emergency pause buybacks
     */
    function emergencyPause() external onlyOwner {
        // In production: implement pausable functionality
        // For now, owner can simply not call executeBuyback()
    }

    /**
     * @notice Update treasury contract
     * @param newTreasury New treasury address
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = ITreasury(newTreasury);
    }

    /**
     * @notice Update DEX router
     * @param newRouter New router address
     */
    function updateDEXRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Invalid router");
        dexRouter = newRouter;
    }
}
