// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UniswapAdapter
 * @notice Adapter for Uniswap V3 concentrated liquidity management
 * @dev Handles LP positions in Uniswap V3 pools for yield generation
 */
contract UniswapAdapter is Ownable {
    using SafeERC20 for IERC20;

    /// @notice TreasuryManager contract address
    address public treasuryManager;

    /// @notice Uniswap V3 NonfungiblePositionManager
    address public constant POSITION_MANAGER = 0x03a520b32c04BF3BEeF7BF5D56D7D8D6b8c7c6Bb; // Base L2

    /// @notice Uniswap V3 SwapRouter
    address public constant SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481; // Base L2

    /// @notice Pool configurations by asset pair
    mapping(bytes32 => PoolConfig) public poolConfigs;

    /// @notice Active LP positions
    mapping(uint256 => LPPosition) public lpPositions;

    /// @notice Position IDs by asset pair
    mapping(bytes32 => uint256[]) public positionsByPair;

    /// @notice Supported asset pairs
    mapping(bytes32 => bool) public supportedPairs;

    /// @notice Total value locked by asset
    mapping(address => uint256) public tvlByAsset;

    /// @notice Pool configuration struct
    struct PoolConfig {
        address token0;
        address token1;
        uint24 fee;
        address pool;
        int24 tickLower;
        int24 tickUpper;
        bool isActive;
    }

    /// @notice LP position struct
    struct LPPosition {
        uint256 tokenId;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 lastRebalance;
        bool isActive;
    }

    /// @notice Events
    event LiquidityAdded(
        uint256 indexed tokenId,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint128 liquidity
    );
    
    event LiquidityRemoved(
        uint256 indexed tokenId,
        uint256 amount0,
        uint256 amount1
    );
    
    event FeesCollected(
        uint256 indexed tokenId,
        uint256 amount0,
        uint256 amount1
    );
    
    event PositionRebalanced(
        uint256 indexed oldTokenId,
        uint256 indexed newTokenId,
        int24 newTickLower,
        int24 newTickUpper
    );

    constructor(address _treasuryManager) Ownable(msg.sender) {
        require(_treasuryManager != address(0), "Invalid treasury manager");
        treasuryManager = _treasuryManager;
    }

    /**
     * @notice Add liquidity to Uniswap V3 pool
     * @param token0 First token address
     * @param token1 Second token address
     * @param amount0 Amount of token0 to add
     * @param amount1 Amount of token1 to add
     * @return tokenId NFT token ID of the position
     */
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external returns (uint256 tokenId) {
        require(msg.sender == treasuryManager, "Only treasury manager");
        require(amount0 > 0 && amount1 > 0, "Invalid amounts");

        bytes32 pairKey = _getPairKey(token0, token1);
        require(supportedPairs[pairKey], "Pair not supported");

        PoolConfig memory config = poolConfigs[pairKey];

        // Transfer tokens from treasury manager
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        // Mock Uniswap V3 position creation
        tokenId = _mockCreatePosition(config, amount0, amount1);

        // Update tracking
        tvlByAsset[token0] += amount0;
        tvlByAsset[token1] += amount1;
        positionsByPair[pairKey].push(tokenId);

        emit LiquidityAdded(tokenId, token0, token1, amount0, amount1, 0);
    }

    /**
     * @notice Remove liquidity from Uniswap V3 position
     * @param tokenId NFT token ID of the position
     * @return amount0 Amount of token0 removed
     * @return amount1 Amount of token1 removed
     */
    function removeLiquidity(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {
        require(msg.sender == treasuryManager, "Only treasury manager");
        
        LPPosition storage position = lpPositions[tokenId];
        require(position.isActive, "Position not active");

        // Mock liquidity removal
        (amount0, amount1) = _mockRemoveLiquidity(tokenId);

        // Update tracking
        tvlByAsset[position.token0] -= amount0;
        tvlByAsset[position.token1] -= amount1;
        position.isActive = false;

        // Transfer tokens back to treasury manager
        IERC20(position.token0).safeTransfer(treasuryManager, amount0);
        IERC20(position.token1).safeTransfer(treasuryManager, amount1);

        emit LiquidityRemoved(tokenId, amount0, amount1);
    }

    /**
     * @notice Collect fees from LP position
     * @param tokenId NFT token ID of the position
     * @return amount0 Fees collected in token0
     * @return amount1 Fees collected in token1
     */
    function collectFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {
        require(msg.sender == treasuryManager, "Only treasury manager");
        
        LPPosition storage position = lpPositions[tokenId];
        require(position.isActive, "Position not active");

        // Mock fee collection
        (amount0, amount1) = _mockCollectFees(tokenId);

        // Transfer fees back to treasury manager
        if (amount0 > 0) {
            IERC20(position.token0).safeTransfer(treasuryManager, amount0);
        }
        if (amount1 > 0) {
            IERC20(position.token1).safeTransfer(treasuryManager, amount1);
        }

        emit FeesCollected(tokenId, amount0, amount1);
    }

    /**
     * @notice Rebalance LP position to optimal range
     * @param tokenId Current position token ID
     * @return newTokenId New position token ID
     */
    function rebalancePosition(uint256 tokenId) external returns (uint256 newTokenId) {
        require(msg.sender == treasuryManager, "Only treasury manager");
        
        LPPosition storage position = lpPositions[tokenId];
        require(position.isActive, "Position not active");

        // Mock rebalancing logic
        newTokenId = _mockRebalancePosition(tokenId);

        emit PositionRebalanced(tokenId, newTokenId, position.tickLower, position.tickUpper);
    }

    /**
     * @notice Get current APY for asset pair
     * @param token0 First token
     * @param token1 Second token
     * @return apy Current APY (scaled by 1e18)
     */
    function getCurrentAPY(address token0, address token1) external view returns (uint256 apy) {
        bytes32 pairKey = _getPairKey(token0, token1);
        require(supportedPairs[pairKey], "Pair not supported");
        
        // Mock APY calculation based on fees and volume
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
     * @notice Get position information
     * @param tokenId Position token ID
     * @return position Position details
     */
    function getPosition(uint256 tokenId) external view returns (LPPosition memory position) {
        position = lpPositions[tokenId];
    }

    /**
     * @notice Get all positions for asset pair
     * @param token0 First token
     * @param token1 Second token
     * @return tokenIds Array of position token IDs
     */
    function getPositionsForPair(address token0, address token1) external view returns (uint256[] memory tokenIds) {
        bytes32 pairKey = _getPairKey(token0, token1);
        tokenIds = positionsByPair[pairKey];
    }

    /**
     * @notice Configure pool for asset pair
     * @param token0 First token address
     * @param token1 Second token address
     * @param fee Pool fee tier
     * @param pool Pool address
     * @param tickLower Lower tick for liquidity range
     * @param tickUpper Upper tick for liquidity range
     */
    function configurePool(
        address token0,
        address token1,
        uint24 fee,
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) external onlyOwner {
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(pool != address(0), "Invalid pool");
        require(tickLower < tickUpper, "Invalid tick range");

        bytes32 pairKey = _getPairKey(token0, token1);
        
        poolConfigs[pairKey] = PoolConfig({
            token0: token0,
            token1: token1,
            fee: fee,
            pool: pool,
            tickLower: tickLower,
            tickUpper: tickUpper,
            isActive: true
        });

        supportedPairs[pairKey] = true;

        // Approve tokens for position manager
        IERC20(token0).approve(POSITION_MANAGER, type(uint256).max);
        IERC20(token1).approve(POSITION_MANAGER, type(uint256).max);
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
     * @param tokenId Position token ID
     */
    function emergencyWithdraw(uint256 tokenId) external onlyOwner {
        LPPosition storage position = lpPositions[tokenId];
        require(position.isActive, "Position not active");

        // Mock emergency withdrawal
        (uint256 amount0, uint256 amount1) = _mockRemoveLiquidity(tokenId);

        position.isActive = false;

        // Transfer to owner for manual handling
        IERC20(position.token0).safeTransfer(owner(), amount0);
        IERC20(position.token1).safeTransfer(owner(), amount1);

        emit LiquidityRemoved(tokenId, amount0, amount1);
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

    // Mock functions for Uniswap V3 integration

    /**
     * @notice Mock position creation
     */
    function _mockCreatePosition(
        PoolConfig memory config,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 tokenId) {
        tokenId = uint256(keccak256(abi.encodePacked(block.timestamp, config.token0, config.token1)));
        
        lpPositions[tokenId] = LPPosition({
            tokenId: tokenId,
            token0: config.token0,
            token1: config.token1,
            fee: config.fee,
            tickLower: config.tickLower,
            tickUpper: config.tickUpper,
            liquidity: uint128(amount0 + amount1), // Simplified
            token0Amount: amount0,
            token1Amount: amount1,
            lastRebalance: block.timestamp,
            isActive: true
        });
    }

    /**
     * @notice Mock liquidity removal
     */
    function _mockRemoveLiquidity(uint256 tokenId) internal view returns (uint256 amount0, uint256 amount1) {
        LPPosition storage position = lpPositions[tokenId];
        
        // Mock: return 99% of original amounts (1% IL simulation)
        amount0 = (position.token0Amount * 99) / 100;
        amount1 = (position.token1Amount * 99) / 100;
    }

    /**
     * @notice Mock fee collection
     */
    function _mockCollectFees(uint256 tokenId) internal view returns (uint256 amount0, uint256 amount1) {
        LPPosition storage position = lpPositions[tokenId];
        
        // Mock: 0.3% fees on liquidity amounts
        amount0 = (position.token0Amount * 3) / 1000;
        amount1 = (position.token1Amount * 3) / 1000;
    }

    /**
     * @notice Mock position rebalancing
     */
    function _mockRebalancePosition(uint256 tokenId) internal returns (uint256 newTokenId) {
        LPPosition storage oldPosition = lpPositions[tokenId];
        
        // Mock: create new position with updated range
        newTokenId = tokenId + 1;
        
        lpPositions[newTokenId] = LPPosition({
            tokenId: newTokenId,
            token0: oldPosition.token0,
            token1: oldPosition.token1,
            fee: oldPosition.fee,
            tickLower: oldPosition.tickLower - 100, // Widen range
            tickUpper: oldPosition.tickUpper + 100,
            liquidity: oldPosition.liquidity,
            token0Amount: oldPosition.token0Amount,
            token1Amount: oldPosition.token1Amount,
            lastRebalance: block.timestamp,
            isActive: true
        });

        oldPosition.isActive = false;
    }

    /**
     * @notice Mock APY calculation
     */
    function _mockCalculateAPY(address token0, address token1) internal pure returns (uint256 apy) {
        // Mock: return 8% APY for stable pairs, 15% for volatile pairs
        // This would be calculated from actual pool data in production
        apy = 8e16; // 8% APY
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
        
        info = AdapterInfo({
            name: "Uniswap V3",
            version: "1.0.0",
            token0: token0,
            token1: token1,
            pool: config.pool,
            fee: config.fee,
            tvl0: tvlByAsset[token0],
            tvl1: tvlByAsset[token1],
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
        uint24 fee;
        uint256 tvl0;
        uint256 tvl1;
        uint256 apy;
        bool isActive;
        uint256 lastUpdate;
    }
}
