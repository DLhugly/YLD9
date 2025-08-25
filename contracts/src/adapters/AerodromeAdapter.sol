// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AerodromeAdapter
 * @notice Adapter for Aerodrome stable LP strategies
 * @dev Handles LP positions in Aerodrome stable pools for yield generation
 */
contract AerodromeAdapter is Ownable {
    using SafeERC20 for IERC20;

    /// @notice TreasuryManager contract address
    address public treasuryManager;

    /// @notice Aerodrome Router
    address public constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43; // Base L2

    /// @notice Aerodrome Gauge Factory
    address public constant GAUGE_FACTORY = 0x4C5009473AB5233b3a18c82c2C4B6c0C0cDd4b43; // Base L2

    /// @notice Pool configurations by asset pair
    mapping(bytes32 => PoolConfig) public poolConfigs;

    /// @notice Active LP positions
    mapping(bytes32 => LPPosition) public lpPositions;

    /// @notice Supported asset pairs
    mapping(bytes32 => bool) public supportedPairs;

    /// @notice Total value locked by asset
    mapping(address => uint256) public tvlByAsset;

    /// @notice Gauge addresses by pair
    mapping(bytes32 => address) public gaugesByPair;

    /// @notice Pool configuration struct
    struct PoolConfig {
        address token0;
        address token1;
        address pool;
        address gauge;
        bool isStable;
        bool isActive;
        uint256 targetRatio; // Target ratio for token0 (scaled by 1e18)
    }

    /// @notice LP position struct
    struct LPPosition {
        address token0;
        address token1;
        address pool;
        address gauge;
        uint256 lpTokens;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 lastReward;
        uint256 stakedAmount;
        bool isActive;
    }

    /// @notice Events
    event LiquidityAdded(
        address indexed token0,
        address indexed token1,
        address indexed pool,
        uint256 amount0,
        uint256 amount1,
        uint256 lpTokens
    );
    
    event LiquidityRemoved(
        address indexed token0,
        address indexed token1,
        address indexed pool,
        uint256 amount0,
        uint256 amount1,
        uint256 lpTokens
    );
    
    event RewardsClaimed(
        address indexed pool,
        address indexed gauge,
        uint256 rewardAmount
    );
    
    event LPTokensStaked(
        address indexed pool,
        address indexed gauge,
        uint256 amount
    );
    
    event LPTokensUnstaked(
        address indexed pool,
        address indexed gauge,
        uint256 amount
    );

    constructor(address _treasuryManager) Ownable(msg.sender) {
        require(_treasuryManager != address(0), "Invalid treasury manager");
        treasuryManager = _treasuryManager;
    }

    /**
     * @notice Add liquidity to Aerodrome pool
     * @param token0 First token address
     * @param token1 Second token address
     * @param amount0 Amount of token0 to add
     * @param amount1 Amount of token1 to add
     * @param stake Whether to stake LP tokens in gauge
     * @return lpTokens Amount of LP tokens received
     */
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        bool stake
    ) external returns (uint256 lpTokens) {
        require(msg.sender == treasuryManager, "Only treasury manager");
        require(amount0 > 0 && amount1 > 0, "Invalid amounts");

        bytes32 pairKey = _getPairKey(token0, token1);
        require(supportedPairs[pairKey], "Pair not supported");

        PoolConfig memory config = poolConfigs[pairKey];

        // Transfer tokens from treasury manager
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        // Mock Aerodrome liquidity addition
        lpTokens = _mockAddLiquidity(config, amount0, amount1);

        // Update position tracking
        LPPosition storage position = lpPositions[pairKey];
        position.token0 = token0;
        position.token1 = token1;
        position.pool = config.pool;
        position.gauge = config.gauge;
        position.lpTokens += lpTokens;
        position.token0Amount += amount0;
        position.token1Amount += amount1;
        position.isActive = true;

        // Update TVL tracking
        tvlByAsset[token0] += amount0;
        tvlByAsset[token1] += amount1;

        // Stake LP tokens in gauge if requested
        if (stake && config.gauge != address(0)) {
            _stakeLPTokens(pairKey, lpTokens);
        }

        emit LiquidityAdded(token0, token1, config.pool, amount0, amount1, lpTokens);
    }

    /**
     * @notice Remove liquidity from Aerodrome pool
     * @param token0 First token address
     * @param token1 Second token address
     * @param lpTokens Amount of LP tokens to remove
     * @return amount0 Amount of token0 received
     * @return amount1 Amount of token1 received
     */
    function removeLiquidity(
        address token0,
        address token1,
        uint256 lpTokens
    ) external returns (uint256 amount0, uint256 amount1) {
        require(msg.sender == treasuryManager, "Only treasury manager");
        require(lpTokens > 0, "Invalid amount");

        bytes32 pairKey = _getPairKey(token0, token1);
        LPPosition storage position = lpPositions[pairKey];
        require(position.isActive && position.lpTokens >= lpTokens, "Insufficient LP tokens");

        PoolConfig memory config = poolConfigs[pairKey];

        // Unstake LP tokens if they're staked
        if (position.stakedAmount >= lpTokens) {
            _unstakeLPTokens(pairKey, lpTokens);
        }

        // Mock liquidity removal
        (amount0, amount1) = _mockRemoveLiquidity(config, lpTokens);

        // Update position tracking
        position.lpTokens -= lpTokens;
        position.token0Amount -= amount0;
        position.token1Amount -= amount1;

        if (position.lpTokens == 0) {
            position.isActive = false;
        }

        // Update TVL tracking
        tvlByAsset[token0] -= amount0;
        tvlByAsset[token1] -= amount1;

        // Transfer tokens back to treasury manager
        IERC20(token0).safeTransfer(treasuryManager, amount0);
        IERC20(token1).safeTransfer(treasuryManager, amount1);

        emit LiquidityRemoved(token0, token1, config.pool, amount0, amount1, lpTokens);
    }

    /**
     * @notice Claim rewards from gauge
     * @param token0 First token address
     * @param token1 Second token address
     * @return rewardAmount Amount of rewards claimed
     */
    function claimRewards(address token0, address token1) external returns (uint256 rewardAmount) {
        require(msg.sender == treasuryManager, "Only treasury manager");

        bytes32 pairKey = _getPairKey(token0, token1);
        LPPosition storage position = lpPositions[pairKey];
        require(position.isActive && position.stakedAmount > 0, "No staked position");

        PoolConfig memory config = poolConfigs[pairKey];
        require(config.gauge != address(0), "No gauge configured");

        // Mock reward claiming
        rewardAmount = _mockClaimRewards(pairKey);

        position.lastReward = block.timestamp;

        // Transfer rewards back to treasury manager (assume AERO rewards)
        if (rewardAmount > 0) {
            // In production: transfer actual AERO tokens
            // For mock: assume rewards are in USDC
            IERC20(token0).safeTransfer(treasuryManager, rewardAmount);
        }

        emit RewardsClaimed(config.pool, config.gauge, rewardAmount);
    }

    /**
     * @notice Stake LP tokens in gauge
     * @param token0 First token address
     * @param token1 Second token address
     * @param amount Amount of LP tokens to stake
     */
    function stakeLPTokens(address token0, address token1, uint256 amount) external {
        require(msg.sender == treasuryManager, "Only treasury manager");

        bytes32 pairKey = _getPairKey(token0, token1);
        _stakeLPTokens(pairKey, amount);
    }

    /**
     * @notice Unstake LP tokens from gauge
     * @param token0 First token address
     * @param token1 Second token address
     * @param amount Amount of LP tokens to unstake
     */
    function unstakeLPTokens(address token0, address token1, uint256 amount) external {
        require(msg.sender == treasuryManager, "Only treasury manager");

        bytes32 pairKey = _getPairKey(token0, token1);
        _unstakeLPTokens(pairKey, amount);
    }

    /**
     * @notice Get current APY for asset pair (including rewards)
     * @param token0 First token
     * @param token1 Second token
     * @return apy Current APY (scaled by 1e18)
     */
    function getCurrentAPY(address token0, address token1) external view returns (uint256 apy) {
        bytes32 pairKey = _getPairKey(token0, token1);
        require(supportedPairs[pairKey], "Pair not supported");
        
        // Mock APY calculation including trading fees and gauge rewards
        apy = _mockCalculateAPY(token0, token1);
    }

    /**
     * @notice Get total value locked for asset
     * @param asset Asset to get TVL for
     * @return tvl Total value locked
     */
    function getTVL(address asset) external view returns (uint256 tvl) {
        tvl = tvlByAsset[asset];
    }

    /**
     * @notice Get LP position information
     * @param token0 First token
     * @param token1 Second token
     * @return position Position details
     */
    function getPosition(address token0, address token1) external view returns (LPPosition memory position) {
        bytes32 pairKey = _getPairKey(token0, token1);
        position = lpPositions[pairKey];
    }

    /**
     * @notice Get pending rewards for position
     * @param token0 First token
     * @param token1 Second token
     * @return pendingRewards Amount of pending rewards
     */
    function getPendingRewards(address token0, address token1) external view returns (uint256 pendingRewards) {
        bytes32 pairKey = _getPairKey(token0, token1);
        LPPosition storage position = lpPositions[pairKey];
        
        if (!position.isActive || position.stakedAmount == 0) return 0;
        
        // Mock pending rewards calculation
        pendingRewards = _mockGetPendingRewards(pairKey);
    }

    /**
     * @notice Configure pool for asset pair
     * @param token0 First token address
     * @param token1 Second token address
     * @param pool Pool address
     * @param gauge Gauge address (can be zero)
     * @param isStable Whether this is a stable pool
     * @param targetRatio Target ratio for token0 (scaled by 1e18)
     */
    function configurePool(
        address token0,
        address token1,
        address pool,
        address gauge,
        bool isStable,
        uint256 targetRatio
    ) external onlyOwner {
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(pool != address(0), "Invalid pool");
        require(targetRatio <= 1e18, "Invalid target ratio");

        bytes32 pairKey = _getPairKey(token0, token1);
        
        poolConfigs[pairKey] = PoolConfig({
            token0: token0,
            token1: token1,
            pool: pool,
            gauge: gauge,
            isStable: isStable,
            isActive: true,
            targetRatio: targetRatio
        });

        supportedPairs[pairKey] = true;

        if (gauge != address(0)) {
            gaugesByPair[pairKey] = gauge;
        }

        // Approve tokens for router
        IERC20(token0).approve(AERODROME_ROUTER, type(uint256).max);
        IERC20(token1).approve(AERODROME_ROUTER, type(uint256).max);

        // Approve LP tokens for gauge if present
        if (gauge != address(0)) {
            IERC20(pool).approve(gauge, type(uint256).max);
        }
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
     * @notice Emergency withdraw from position
     * @param token0 First token
     * @param token1 Second token
     */
    function emergencyWithdraw(address token0, address token1) external onlyOwner {
        bytes32 pairKey = _getPairKey(token0, token1);
        LPPosition storage position = lpPositions[pairKey];
        require(position.isActive, "Position not active");

        // Unstake all LP tokens first
        if (position.stakedAmount > 0) {
            _unstakeLPTokens(pairKey, position.stakedAmount);
        }

        // Mock emergency withdrawal
        (uint256 amount0, uint256 amount1) = _mockRemoveLiquidity(
            poolConfigs[pairKey], 
            position.lpTokens
        );

        position.isActive = false;
        position.lpTokens = 0;
        position.stakedAmount = 0;

        // Transfer to owner for manual handling
        IERC20(token0).safeTransfer(owner(), amount0);
        IERC20(token1).safeTransfer(owner(), amount1);

        emit LiquidityRemoved(token0, token1, poolConfigs[pairKey].pool, amount0, amount1, position.lpTokens);
    }

    // Internal helper functions

    /**
     * @notice Get pair key for two tokens
     */
    function _getPairKey(address token0, address token1) internal pure returns (bytes32) {
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        return keccak256(abi.encodePacked(token0, token1));
    }

    /**
     * @notice Internal stake LP tokens
     */
    function _stakeLPTokens(bytes32 pairKey, uint256 amount) internal {
        LPPosition storage position = lpPositions[pairKey];
        PoolConfig memory config = poolConfigs[pairKey];
        
        require(config.gauge != address(0), "No gauge configured");
        require(position.lpTokens >= amount, "Insufficient LP tokens");

        // Mock staking
        position.stakedAmount += amount;

        emit LPTokensStaked(config.pool, config.gauge, amount);
    }

    /**
     * @notice Internal unstake LP tokens
     */
    function _unstakeLPTokens(bytes32 pairKey, uint256 amount) internal {
        LPPosition storage position = lpPositions[pairKey];
        PoolConfig memory config = poolConfigs[pairKey];
        
        require(position.stakedAmount >= amount, "Insufficient staked tokens");

        // Mock unstaking
        position.stakedAmount -= amount;

        emit LPTokensUnstaked(config.pool, config.gauge, amount);
    }

    // Mock functions for Aerodrome integration

    /**
     * @notice Mock liquidity addition
     */
    function _mockAddLiquidity(
        PoolConfig memory config,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint256 lpTokens) {
        // Mock: simple calculation for stable pools
        if (config.isStable) {
            lpTokens = amount0 + amount1; // 1:1 for stables
        } else {
            lpTokens = (amount0 * amount1) / 1e6; // Simplified geometric mean
        }
    }

    /**
     * @notice Mock liquidity removal
     */
    function _mockRemoveLiquidity(
        PoolConfig memory config,
        uint256 lpTokens
    ) internal view returns (uint256 amount0, uint256 amount1) {
        bytes32 pairKey = _getPairKey(config.token0, config.token1);
        LPPosition storage position = lpPositions[pairKey];
        
        if (position.lpTokens == 0) return (0, 0);
        
        // Proportional withdrawal
        uint256 share = (lpTokens * 1e18) / position.lpTokens;
        amount0 = (position.token0Amount * share) / 1e18;
        amount1 = (position.token1Amount * share) / 1e18;
    }

    /**
     * @notice Mock reward claiming
     */
    function _mockClaimRewards(bytes32 pairKey) internal view returns (uint256 rewardAmount) {
        LPPosition storage position = lpPositions[pairKey];
        
        if (position.stakedAmount == 0) return 0;
        
        // Mock: 10% APR on staked amount
        uint256 timeElapsed = block.timestamp - position.lastReward;
        if (timeElapsed == 0) timeElapsed = 1 days; // Default for first claim
        
        rewardAmount = (position.stakedAmount * 10 * timeElapsed) / (100 * 365 days);
    }

    /**
     * @notice Mock pending rewards calculation
     */
    function _mockGetPendingRewards(bytes32 pairKey) internal view returns (uint256 pendingRewards) {
        LPPosition storage position = lpPositions[pairKey];
        
        if (position.stakedAmount == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - position.lastReward;
        pendingRewards = (position.stakedAmount * 10 * timeElapsed) / (100 * 365 days);
    }

    /**
     * @notice Mock APY calculation
     */
    function _mockCalculateAPY(address token0, address token1) internal view returns (uint256 apy) {
        bytes32 pairKey = _getPairKey(token0, token1);
        PoolConfig memory config = poolConfigs[pairKey];
        
        if (config.isStable) {
            // Stable pools: 6% trading fees + 10% gauge rewards if staked
            apy = config.gauge != address(0) ? 16e16 : 6e16; // 16% or 6%
        } else {
            // Volatile pools: 12% trading fees + 15% gauge rewards if staked
            apy = config.gauge != address(0) ? 27e16 : 12e16; // 27% or 12%
        }
    }

    /**
     * @notice Check if adapter is healthy
     * @param token0 First token
     * @param token1 Second token
     * @return healthy Whether adapter is functioning properly
     */
    function isHealthy(address token0, address token1) external view returns (bool healthy) {
        bytes32 pairKey = _getPairKey(token0, token1);
        if (!supportedPairs[pairKey]) return false;
        
        PoolConfig memory config = poolConfigs[pairKey];
        if (!config.isActive) return false;
        
        // Mock health check - in production verify pool liquidity and activity
        healthy = true;
    }

    /**
     * @notice Get adapter information
     * @param token0 First token
     * @param token1 Second token
     * @return info Adapter information struct
     */
    function getAdapterInfo(address token0, address token1) external view returns (AdapterInfo memory info) {
        bytes32 pairKey = _getPairKey(token0, token1);
        PoolConfig memory config = poolConfigs[pairKey];
        LPPosition storage position = lpPositions[pairKey];
        
        info = AdapterInfo({
            name: "Aerodrome",
            version: "1.0.0",
            token0: token0,
            token1: token1,
            pool: config.pool,
            gauge: config.gauge,
            isStable: config.isStable,
            tvl0: tvlByAsset[token0],
            tvl1: tvlByAsset[token1],
            lpTokens: position.lpTokens,
            stakedAmount: position.stakedAmount,
            apy: supportedPairs[pairKey] ? _mockCalculateAPY(token0, token1) : 0,
            isActive: config.isActive,
            lastUpdate: block.timestamp
        });
    }

    /**
     * @notice Adapter information struct
     */
    struct AdapterInfo {
        string name;
        string version;
        address token0;
        address token1;
        address pool;
        address gauge;
        bool isStable;
        uint256 tvl0;
        uint256 tvl1;
        uint256 lpTokens;
        uint256 stakedAmount;
        uint256 apy;
        bool isActive;
        uint256 lastUpdate;
    }
}
