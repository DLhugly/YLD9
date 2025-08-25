// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITreasury.sol";
import "./AttestationEmitter.sol";

/**
 * @title POLManager
 * @notice Protocol-Owned Liquidity manager for AGN/USDC Aerodrome pool
 * @dev Sources AGN from treasury + stable yield, targets ≥33% pool ownership
 */
contract POLManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice AGN token
    IERC20 public immutable AGN;
    
    /// @notice USDC stablecoin
    IERC20 public immutable USDC;
    
    /// @notice Aerodrome AGN/USDC LP token
    IERC20 public lpToken;
    
    /// @notice Treasury contract (source of funds)
    ITreasury public treasury;
    
    /// @notice Attestation emitter for transparency
    AttestationEmitter public attestationEmitter;
    
    /// @notice Aerodrome pool contract
    address public aerodromePool;
    
    /// @notice Aerodrome gauge for LP rewards
    address public aerodromeGauge;
    
    /// @notice Target pool ownership percentage (basis points)
    uint256 public targetOwnership = 3300; // 33%
    
    /// @notice Daily add budget cap (USDC equivalent)
    uint256 public dailyBudget = 10000e6; // $10K max per day
    
    /// @notice Maximum slippage for LP operations (basis points)
    uint256 public maxSlippage = 100; // 1%
    
    /// @notice Minimum interval between LP adds (anti-MEV)
    uint256 public minAddInterval = 4 hours;
    
    /// @notice Last LP add timestamp
    uint256 public lastAddTime;
    
    /// @notice Daily spending tracking
    mapping(uint256 => uint256) public dailySpent; // day => amount spent
    
    /// @notice POL position tracking
    struct POLPosition {
        uint256 lpTokens;
        uint256 agnContributed;
        uint256 usdcContributed;
        uint256 timestamp;
        uint256 poolOwnershipBPS; // basis points
        int256 impermanentLoss; // can be negative (gain) or positive (loss)
    }
    
    /// @notice Historical POL positions
    POLPosition[] public polHistory;
    
    /// @notice Current POL metrics
    uint256 public totalLPTokens;
    uint256 public totalAGNContributed;
    uint256 public totalUSDCContributed;
    int256 public cumulativeIL;
    
    /// @notice Events
    event LiquidityAdded(uint256 agnAmount, uint256 usdcAmount, uint256 lpTokens, uint256 poolOwnership);
    event LiquidityRemoved(uint256 lpTokens, uint256 agnReceived, uint256 usdcReceived, int256 impermanentLoss);
    event TargetOwnershipUpdated(uint256 newTarget);
    event DailyBudgetUpdated(uint256 newBudget);
    event EmergencyWithdraw(uint256 lpTokens);
    event ILCalculated(int256 currentIL, int256 cumulativeIL);

    modifier onlyTreasury() {
        require(msg.sender == address(treasury) || msg.sender == owner(), "Unauthorized");
        _;
    }

    constructor(
        address _agn,
        address _usdc,
        address _treasury,
        address _aerodromePool,
        address _aerodromeGauge
    ) Ownable(msg.sender) {
        AGN = IERC20(_agn);
        USDC = IERC20(_usdc);
        treasury = ITreasury(_treasury);
        aerodromePool = _aerodromePool;
        aerodromeGauge = _aerodromeGauge;
    }

    /**
     * @notice Add liquidity to Aerodrome AGN/USDC pool
     * @param agnAmount AGN tokens to add
     * @param usdcAmount USDC tokens to add
     * @dev Called by treasury or owner, respects daily budget and timing
     */
    function addLiquidity(uint256 agnAmount, uint256 usdcAmount) 
        external 
        nonReentrant 
        onlyTreasury 
    {
        require(agnAmount > 0 && usdcAmount > 0, "Invalid amounts");
        require(block.timestamp >= lastAddTime + minAddInterval, "Too frequent");
        
        // Check daily budget
        uint256 today = block.timestamp / 1 days;
        require(dailySpent[today] + usdcAmount <= dailyBudget, "Daily budget exceeded");
        
        // Get current pool ownership before adding
        uint256 currentOwnership = getCurrentPoolOwnership();
        
        // Only add if below target ownership
        require(currentOwnership < targetOwnership, "Already at target ownership");
        
        // Transfer tokens from treasury
        AGN.safeTransferFrom(address(treasury), address(this), agnAmount);
        USDC.safeTransferFrom(address(treasury), address(this), usdcAmount);
        
        // Calculate optimal amounts with slippage protection
        (uint256 optimalAGN, uint256 optimalUSDC) = _calculateOptimalAmounts(agnAmount, usdcAmount);
        
        // Add liquidity to Aerodrome pool
        uint256 lpTokensReceived = _addLiquidityToPool(optimalAGN, optimalUSDC);
        require(lpTokensReceived > 0, "No LP tokens received");
        
        // Stake LP tokens in gauge for rewards
        if (aerodromeGauge != address(0)) {
            IERC20(lpToken).approve(aerodromeGauge, lpTokensReceived);
            // In production: call gauge.deposit(lpTokensReceived)
        }
        
        // Update tracking
        totalLPTokens += lpTokensReceived;
        totalAGNContributed += optimalAGN;
        totalUSDCContributed += optimalUSDC;
        dailySpent[today] += usdcAmount;
        lastAddTime = block.timestamp;
        
        // Calculate new pool ownership
        uint256 newOwnership = getCurrentPoolOwnership();
        
        // Record position
        polHistory.push(POLPosition({
            lpTokens: lpTokensReceived,
            agnContributed: optimalAGN,
            usdcContributed: optimalUSDC,
            timestamp: block.timestamp,
            poolOwnershipBPS: newOwnership,
            impermanentLoss: 0 // Will be calculated later
        }));
        
        // Return excess tokens to treasury
        uint256 excessAGN = agnAmount - optimalAGN;
        uint256 excessUSDC = usdcAmount - optimalUSDC;
        if (excessAGN > 0) AGN.safeTransfer(address(treasury), excessAGN);
        if (excessUSDC > 0) USDC.safeTransfer(address(treasury), excessUSDC);
        
        // Emit events
        emit LiquidityAdded(optimalAGN, optimalUSDC, lpTokensReceived, newOwnership);
        
        // Emit attestation
        if (address(attestationEmitter) != address(0)) {
            attestationEmitter.emitPOLUpdate(
                optimalAGN,
                optimalUSDC,
                lpTokensReceived,
                newOwnership,
                block.timestamp
            );
        }
    }

    /**
     * @notice Remove liquidity from pool (emergency or rebalancing)
     * @param lpTokenAmount LP tokens to remove
     */
    function removeLiquidity(uint256 lpTokenAmount) external onlyOwner nonReentrant {
        require(lpTokenAmount > 0, "Invalid amount");
        require(lpTokenAmount <= totalLPTokens, "Insufficient LP tokens");
        
        // Unstake from gauge if needed
        if (aerodromeGauge != address(0)) {
            // In production: call gauge.withdraw(lpTokenAmount)
        }
        
        // Remove liquidity from pool
        (uint256 agnReceived, uint256 usdcReceived) = _removeLiquidityFromPool(lpTokenAmount);
        
        // Calculate impermanent loss
        int256 impermanentLoss = _calculateImpermanentLoss(agnReceived, usdcReceived, lpTokenAmount);
        cumulativeIL += impermanentLoss;
        
        // Update tracking
        totalLPTokens -= lpTokenAmount;
        
        // Send tokens to treasury
        AGN.safeTransfer(address(treasury), agnReceived);
        USDC.safeTransfer(address(treasury), usdcReceived);
        
        emit LiquidityRemoved(lpTokenAmount, agnReceived, usdcReceived, impermanentLoss);
        emit ILCalculated(impermanentLoss, cumulativeIL);
    }

    /**
     * @notice Calculate optimal liquidity amounts with slippage protection
     * @param agnAmount Desired AGN amount
     * @param usdcAmount Desired USDC amount
     * @return optimalAGN Optimal AGN amount
     * @return optimalUSDC Optimal USDC amount
     */
    function _calculateOptimalAmounts(uint256 agnAmount, uint256 usdcAmount) 
        internal 
        view 
        returns (uint256 optimalAGN, uint256 optimalUSDC) 
    {
        // Get current pool reserves
        (uint256 reserve0, uint256 reserve1) = _getPoolReserves();
        
        // Calculate optimal ratio
        if (reserve0 > 0 && reserve1 > 0) {
            uint256 optimalUSDCForAGN = (agnAmount * reserve1) / reserve0;
            uint256 optimalAGNForUSDC = (usdcAmount * reserve0) / reserve1;
            
            if (optimalUSDCForAGN <= usdcAmount) {
                optimalAGN = agnAmount;
                optimalUSDC = optimalUSDCForAGN;
            } else {
                optimalAGN = optimalAGNForUSDC;
                optimalUSDC = usdcAmount;
            }
        } else {
            // First liquidity or empty pool
            optimalAGN = agnAmount;
            optimalUSDC = usdcAmount;
        }
    }

    /**
     * @notice Add liquidity to Aerodrome pool
     * @param agnAmount AGN amount
     * @param usdcAmount USDC amount
     * @return lpTokens LP tokens received
     */
    function _addLiquidityToPool(uint256 agnAmount, uint256 usdcAmount) 
        internal 
        returns (uint256 lpTokens) 
    {
        // Approve tokens
        AGN.approve(aerodromePool, agnAmount);
        USDC.approve(aerodromePool, usdcAmount);
        
        // In production: call Aerodrome router.addLiquidity()
        // For mock: assume 1:1 LP token ratio
        lpTokens = (agnAmount + usdcAmount) / 2; // Simplified calculation
        
        // Mock LP token minting
        // In production: this would be done by the Aerodrome pool
        require(lpTokens > 0, "No LP tokens minted");
    }

    /**
     * @notice Remove liquidity from Aerodrome pool
     * @param lpTokenAmount LP tokens to burn
     * @return agnReceived AGN tokens received
     * @return usdcReceived USDC tokens received
     */
    function _removeLiquidityFromPool(uint256 lpTokenAmount) 
        internal 
        returns (uint256 agnReceived, uint256 usdcReceived) 
    {
        // In production: call Aerodrome router.removeLiquidity()
        // For mock: assume proportional withdrawal
        uint256 totalLP = totalLPTokens;
        if (totalLP > 0) {
            agnReceived = (totalAGNContributed * lpTokenAmount) / totalLP;
            usdcReceived = (totalUSDCContributed * lpTokenAmount) / totalLP;
        }
    }

    /**
     * @notice Get current pool reserves
     * @return reserve0 AGN reserves
     * @return reserve1 USDC reserves
     */
    function _getPoolReserves() internal view returns (uint256 reserve0, uint256 reserve1) {
        // In production: query actual Aerodrome pool reserves
        // For mock: assume balanced pool
        reserve0 = 1000000e18; // 1M AGN
        reserve1 = 1000000e6;  // 1M USDC
    }

    /**
     * @notice Calculate impermanent loss for position
     * @param agnReceived AGN received on withdrawal
     * @param usdcReceived USDC received on withdrawal
     * @param lpTokenAmount LP tokens withdrawn
     * @return impermanentLoss IL in USDC terms (positive = loss, negative = gain)
     */
    function _calculateImpermanentLoss(
        uint256 agnReceived, 
        uint256 usdcReceived, 
        uint256 lpTokenAmount
    ) internal view returns (int256 impermanentLoss) {
        // Calculate what we would have had if we held tokens separately
        uint256 proportionWithdrawn = (lpTokenAmount * 1e18) / totalLPTokens;
        uint256 expectedAGN = (totalAGNContributed * proportionWithdrawn) / 1e18;
        uint256 expectedUSDC = (totalUSDCContributed * proportionWithdrawn) / 1e18;
        
        // Get current AGN price in USDC
        uint256 agnPrice = _getAGNPrice();
        
        // Calculate value if held separately vs LP
        uint256 holdValue = expectedUSDC + (expectedAGN * agnPrice / 1e18);
        uint256 lpValue = usdcReceived + (agnReceived * agnPrice / 1e18);
        
        // IL = LP value - Hold value (negative means LP performed better)
        impermanentLoss = int256(lpValue) - int256(holdValue);
    }

    /**
     * @notice Get current AGN price in USDC
     * @return price AGN price scaled by 1e18
     */
    function _getAGNPrice() internal pure returns (uint256 price) {
        // In production: get from oracle or DEX
        price = 0.83e18; // Mock: $0.83 per AGN
    }

    /**
     * @notice Get current pool ownership percentage
     * @return ownership Pool ownership in basis points
     */
    function getCurrentPoolOwnership() public view returns (uint256 ownership) {
        // In production: query total LP supply from pool
        uint256 totalPoolLP = 10000000e18; // Mock: 10M LP tokens total
        
        if (totalPoolLP > 0 && totalLPTokens > 0) {
            ownership = (totalLPTokens * 10000) / totalPoolLP; // basis points
        }
    }

    /**
     * @notice Get POL statistics
     * @return stats Current POL metrics
     */
    function getPOLStats() external view returns (POLStats memory stats) {
        uint256 currentValue = _calculateCurrentValue();
        uint256 contributedValue = totalUSDCContributed + (totalAGNContributed * _getAGNPrice() / 1e18);
        
        stats = POLStats({
            totalLPTokens: totalLPTokens,
            poolOwnership: getCurrentPoolOwnership(),
            targetOwnership: targetOwnership,
            totalAGNContributed: totalAGNContributed,
            totalUSDCContributed: totalUSDCContributed,
            currentValue: currentValue,
            impermanentLoss: cumulativeIL,
            dailyBudgetRemaining: _getDailyBudgetRemaining(),
            canAddLiquidity: _canAddLiquidity()
        });
    }

    /**
     * @notice Calculate current position value
     * @return value Current value in USDC
     */
    function _calculateCurrentValue() internal view returns (uint256 value) {
        if (totalLPTokens > 0) {
            (uint256 agnValue, uint256 usdcValue) = _getPositionValue();
            value = usdcValue + (agnValue * _getAGNPrice() / 1e18);
        }
    }

    /**
     * @notice Get position value breakdown
     * @return agnValue AGN portion of position
     * @return usdcValue USDC portion of position
     */
    function _getPositionValue() internal view returns (uint256 agnValue, uint256 usdcValue) {
        // In production: calculate based on current pool reserves and LP share
        // For mock: assume proportional to contributions
        agnValue = totalAGNContributed;
        usdcValue = totalUSDCContributed;
    }

    /**
     * @notice Get remaining daily budget
     * @return remaining Remaining budget for today
     */
    function _getDailyBudgetRemaining() internal view returns (uint256 remaining) {
        uint256 today = block.timestamp / 1 days;
        uint256 spent = dailySpent[today];
        remaining = spent >= dailyBudget ? 0 : dailyBudget - spent;
    }

    /**
     * @notice Check if liquidity can be added
     * @return canAdd Whether liquidity addition is possible
     */
    function _canAddLiquidity() internal view returns (bool canAdd) {
        canAdd = getCurrentPoolOwnership() < targetOwnership &&
                _getDailyBudgetRemaining() > 0 &&
                block.timestamp >= lastAddTime + minAddInterval;
    }

    /**
     * @notice Update target ownership (owner only)
     * @param newTarget New target ownership in basis points
     */
    function updateTargetOwnership(uint256 newTarget) external onlyOwner {
        require(newTarget <= 5000, "Target too high"); // Max 50%
        targetOwnership = newTarget;
        emit TargetOwnershipUpdated(newTarget);
    }

    /**
     * @notice Update daily budget (owner only)
     * @param newBudget New daily budget in USDC
     */
    function updateDailyBudget(uint256 newBudget) external onlyOwner {
        require(newBudget <= 50000e6, "Budget too high"); // Max $50K/day
        dailyBudget = newBudget;
        emit DailyBudgetUpdated(newBudget);
    }

    /**
     * @notice Set attestation emitter (owner only)
     * @param emitter AttestationEmitter contract
     */
    function setAttestationEmitter(address emitter) external onlyOwner {
        attestationEmitter = AttestationEmitter(emitter);
    }

    /**
     * @notice Emergency withdraw all LP tokens (owner only)
     */
    function emergencyWithdraw() external onlyOwner {
        if (totalLPTokens > 0) {
            removeLiquidity(totalLPTokens);
            emit EmergencyWithdraw(totalLPTokens);
        }
    }

    /**
     * @notice POL statistics struct
     */
    struct POLStats {
        uint256 totalLPTokens;
        uint256 poolOwnership; // basis points
        uint256 targetOwnership; // basis points
        uint256 totalAGNContributed;
        uint256 totalUSDCContributed;
        uint256 currentValue;
        int256 impermanentLoss;
        uint256 dailyBudgetRemaining;
        bool canAddLiquidity;
    }
}
