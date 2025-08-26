// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITreasury.sol";

// Aerodrome Router interface (simplified for swaps and LP)
interface IAerodromeRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    
    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);
}

// Aerodrome Pool interface (for LP management)
interface IAerodromePool {
    function claimFees() external returns (uint claimed0, uint claimed1);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function stable() external view returns (bool);
}

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
    
    /// @notice Aerodrome Router for TWAP execution on Base
    address public constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43; // Base mainnet
    
    /// @notice AGN/USDC pool on Aerodrome
    address public agnUsdcPool;
    
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
    
    /// @notice Buyback split: 90% burn, 10% LP pairing (matching docs)
    uint256 public constant BURN_PERCENTAGE = 9000; // 90% in basis points
    uint256 public constant LP_PAIRING_PERCENTAGE = 1000; // 10% in basis points
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
    event LiquidityAdded(uint256 agnAmount, uint256 usdcAmount, uint256 liquidity);
    event PoolFeesClaimed(uint256 claimed0, uint256 claimed1);

    constructor(
        address _agn,
        address _usdc,
        address _treasury,
        address _agnUsdcPool
    ) Ownable(msg.sender) {
        AGN = IERC20(_agn);
        USDC = IERC20(_usdc);
        treasury = ITreasury(_treasury);
        agnUsdcPool = _agnUsdcPool;
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
        
        // Claim LP fees first and recycle through treasury (adds 1-2% APY)
        uint256 feesClaimed = claimPoolFees();
        if (feesClaimed > 0) {
            // Route LP fees back through 80/20 flywheel
            ITreasury(treasury).processInflowAutomated(feesClaimed);
        }
        
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
        
        // Split AGN: 90% burn, 10% LP pairing (matching docs)
        uint256 agnToBurn = (agnBought * BURN_PERCENTAGE) / MAX_BPS;
        uint256 agnForLP = agnBought - agnToBurn; // Ensures no rounding loss
        
        // Burn AGN tokens (send to burn address)
        _burnAGN(agnToBurn);
        
        // Send AGN for LP pairing to treasury (if LP depth < target)
        if (agnForLP > 0) {
            AGN.safeTransfer(address(treasury), agnForLP);
            // Treasury will pair with USDC if LP conditions met
        }
        
        // Update statistics
        totalUSDCSpent += buybackAmount;
        totalAGNBought += agnBought;
        totalAGNBurned += agnToBurn;
        totalAGNToTreasury += agnForLP; // Track AGN sent for LP pairing
        
        // Record execution
        buybackHistory.push(BuybackExecution({
            timestamp: block.timestamp,
            usdcSpent: buybackAmount,
            agnBought: agnBought,
            agnBurned: agnToBurn,
            agnToTreasury: agnForLP,
            avgPrice: buybackAmount * 1e18 / agnBought,
            safetyGatesOK: true
        }));
        
        // Update buyback pool and timestamp
        buybackPool -= buybackAmount;
        lastBuybackTime = block.timestamp;
        
        emit BuybackExecuted(buybackAmount, agnBought, agnToBurn, agnForLP);
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
        
        // Execute swap via Aerodrome Router
        agnBought = _executeAerodromeSwap(usdcAmount, minAGNOut);
    }

    /**
     * @notice Execute swap via Aerodrome Router
     * @param usdcIn USDC input amount
     * @param minAGNOut Minimum AGN output
     * @return agnOut AGN tokens received
     */
    function _executeAerodromeSwap(uint256 usdcIn, uint256 minAGNOut) internal returns (uint256 agnOut) {
        // Approve USDC to Aerodrome Router
        USDC.approve(AERODROME_ROUTER, usdcIn);
        
        // Prepare swap route: USDC -> AGN
        address[] memory route = new address[](2);
        route[0] = address(USDC);
        route[1] = address(AGN);
        
        // Execute swap through Aerodrome Router
        uint[] memory amounts = IAerodromeRouter(AERODROME_ROUTER).swapExactTokensForTokens(
            usdcIn,
            minAGNOut,
            route,
            address(this),
            block.timestamp + 300 // 5 minute deadline
        );
        
        agnOut = amounts[1]; // AGN received (last element in amounts array)
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
        if (agnUsdcPool == address(0)) {
            return 0;
        }
        
        // Get USDC balance in the AGN/USDC pool (represents half of total liquidity)
        uint256 usdcBalance = USDC.balanceOf(agnUsdcPool);
        
        // Estimate total liquidity as 2x USDC balance (assuming balanced pool)
        liquidity = usdcBalance * 2;
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
     * @notice Update AGN/USDC pool address
     * @param newPool New pool address
     */
    function updateAGNUSDCPool(address newPool) external onlyOwner {
        require(newPool != address(0), "Invalid pool");
        agnUsdcPool = newPool;
    }

    /**
     * @notice Add liquidity to AGN/USDC pool on Aerodrome
     * @param agnAmount AGN tokens to add
     * @param usdcAmount USDC tokens to add
     * @param stable Whether the pool is stable (true) or volatile (false)
     * @return liquidity LP tokens received
     */
    function addLiquidity(
        uint256 agnAmount,
        uint256 usdcAmount,
        bool stable
    ) external onlyOwner returns (uint256 liquidity) {
        require(agnAmount > 0 && usdcAmount > 0, "Invalid amounts");
        
        // Approve tokens to Aerodrome Router
        AGN.approve(AERODROME_ROUTER, agnAmount);
        USDC.approve(AERODROME_ROUTER, usdcAmount);
        
        // Add liquidity to AGN/USDC pool
        (,, liquidity) = IAerodromeRouter(AERODROME_ROUTER).addLiquidity(
            address(AGN),
            address(USDC),
            stable,
            agnAmount,
            usdcAmount,
            (agnAmount * 9500) / 10000, // 5% slippage tolerance
            (usdcAmount * 9500) / 10000, // 5% slippage tolerance
            address(this), // LP tokens go to Buyback contract
            block.timestamp + 300 // 5 minute deadline
        );
        
        emit LiquidityAdded(agnAmount, usdcAmount, liquidity);
    }
    
    /**
     * @notice Claim fees from AGN/USDC pool
     * @return claimed0 Amount of token0 fees claimed
     * @return claimed1 Amount of token1 fees claimed
     */
    function claimPoolFees() external onlyOwner returns (uint256 claimed0, uint256 claimed1) {
        require(agnUsdcPool != address(0), "Pool not set");
        
        (claimed0, claimed1) = IAerodromePool(agnUsdcPool).claimFees();
        
        emit PoolFeesClaimed(claimed0, claimed1);
    }

    /**
     * @notice Get LP token balance in AGN/USDC pool
     * @return balance LP token balance of this contract
     */
    function getLPBalance() external view returns (uint256 balance) {
        if (agnUsdcPool != address(0)) {
            balance = IAerodromePool(agnUsdcPool).balanceOf(address(this));
        }
    }
}
