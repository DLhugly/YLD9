// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITreasury.sol";

/**
 * @title Treasury
 * @notice Manages ETH accumulation, DCA purchases, FX arbitrage, and ETH staking
 * @dev Implements MicroStrategy-style ETH treasury with safety gates
 */
contract Treasury is ITreasury, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Supported stablecoin addresses
    address public immutable USDC;
    address public immutable USD1;
    address public immutable EURC;
    address public immutable WETH;

    /// @notice Stablecoin balances
    mapping(address => uint256) public stablecoinBalances;
    
    /// @notice ETH balances
    uint256 public liquidETH;
    uint256 public stakedETH;
    uint256 public stakingRewards;
    
    /// @notice Monthly operational expenses in USDC
    uint256 public monthlyOpex = 50000e6; // $50k USDC
    
    /// @notice Weekly DCA cap in USDC
    uint256 public weeklyDCACap = 5000e6; // $5k USDC
    
    /// @notice FX arbitrage threshold (basis points)
    uint256 public fxArbThreshold = 10; // 0.1%
    
    /// @notice ETH staking allocation limit (basis points)
    uint256 public ethStakingLimit = 2000; // 20%
    
    /// @notice Minimum coverage ratio (scaled by 1e18)
    uint256 public minCoverageRatio = 1.2e18; // 1.2x
    
    /// @notice Minimum runway months
    uint256 public minRunwayMonths = 6;
    
    /// @notice Outstanding ATN principal
    uint256 public outstandingATN;
    
    /// @notice ETH price oracle (for simplicity, using manual updates)
    uint256 public ethPrice = 3000e6; // $3000 USDC per ETH
    
    /// @notice Maximum basis points
    uint256 public constant MAX_BPS = 10000;
    
    /// @notice Events
    event DCAPurchase(uint256 usdcAmount, uint256 ethAmount, uint256 ethPrice);
    event FXArbitrage(address fromAsset, address toAsset, uint256 amount, uint256 profit);
    event ETHStaked(uint256 amount, uint256 totalStaked);
    event StakingRewardsClaimed(uint256 amount);
    event SafetyGateTriggered(string gate, bool status);
    event ParameterUpdated(string param, uint256 value);

    constructor(
        address _usdc,
        address _usd1,
        address _eurc,
        address _weth
    ) Ownable(msg.sender) {
        USDC = _usdc;
        USD1 = _usd1;
        EURC = _eurc;
        WETH = _weth;
    }

    /**
     * @notice Execute weekly DCA purchase of ETH
     * @param amount Amount of USDC to convert to ETH
     * @return ethPurchased Amount of ETH purchased
     */
    function weeklyDCA(uint256 amount) external override onlyOwner nonReentrant returns (uint256 ethPurchased) {
        require(amount <= weeklyDCACap, "Exceeds DCA cap");
        require(stablecoinBalances[USDC] >= amount, "Insufficient USDC");
        
        // Check safety gates
        (bool runwayOK, bool crOK) = getSafetyGateStatus();
        require(runwayOK, "Runway too low for DCA");
        
        // Calculate ETH to purchase (simplified - in production use DEX)
        ethPurchased = (amount * 1e18) / ethPrice;
        
        // Update balances
        stablecoinBalances[USDC] -= amount;
        liquidETH += ethPurchased;
        
        // In production: execute DEX swap here
        // IERC20(USDC).safeTransfer(dexRouter, amount);
        
        emit DCAPurchase(amount, ethPurchased, ethPrice);
    }

    /**
     * @notice Execute FX arbitrage across stablecoin pairs
     * @param fromAsset Source stablecoin
     * @param toAsset Target stablecoin
     * @param amount Amount to arbitrage
     * @return profit Profit from arbitrage
     */
    function executeFXArbitrage(
        address fromAsset,
        address toAsset,
        uint256 amount
    ) external override onlyOwner nonReentrant returns (uint256 profit) {
        require(_isSupportedAsset(fromAsset) && _isSupportedAsset(toAsset), "Unsupported asset");
        require(stablecoinBalances[fromAsset] >= amount, "Insufficient balance");
        
        // Get implied rates (simplified - in production use Chainlink/DEX)
        uint256 impliedRate = _getImpliedFXRate(fromAsset, toAsset);
        uint256 spotRate = 1e18; // Assume 1:1 for stablecoins
        
        // Check if arbitrage opportunity exists
        uint256 deviation = impliedRate > spotRate ? 
            impliedRate - spotRate : spotRate - impliedRate;
        require((deviation * MAX_BPS) / spotRate >= fxArbThreshold, "Insufficient arbitrage opportunity");
        
        // Execute arbitrage (simplified)
        uint256 receivedAmount = (amount * impliedRate) / 1e18;
        profit = receivedAmount > amount ? receivedAmount - amount : 0;
        
        // Update balances
        stablecoinBalances[fromAsset] -= amount;
        stablecoinBalances[toAsset] += receivedAmount;
        
        emit FXArbitrage(fromAsset, toAsset, amount, profit);
    }

    /**
     * @notice Stake portion of ETH holdings
     * @param amount Amount of ETH to stake
     * @return stakedAmount Amount actually staked
     */
    function stakeETH(uint256 amount) external override onlyOwner nonReentrant returns (uint256 stakedAmount) {
        require(liquidETH >= amount, "Insufficient liquid ETH");
        
        uint256 totalETH = liquidETH + stakedETH;
        uint256 maxStakeable = (totalETH * ethStakingLimit) / MAX_BPS;
        
        stakedAmount = stakedETH + amount > maxStakeable ? 
            maxStakeable - stakedETH : amount;
        
        require(stakedAmount > 0, "No ETH to stake");
        
        // Update balances
        liquidETH -= stakedAmount;
        stakedETH += stakedAmount;
        
        // In production: call staking contract (Lido/Rocket Pool)
        // ILido(lidoContract).submit{value: stakedAmount}(address(0));
        
        emit ETHStaked(stakedAmount, stakedETH);
    }

    /**
     * @notice Claim staking rewards
     * @return rewards Amount of rewards claimed
     */
    function claimStakingRewards() external onlyOwner returns (uint256 rewards) {
        // In production: claim from staking contract
        // rewards = ILido(lidoContract).balanceOf(address(this)) - stakedETH;
        rewards = (stakedETH * 4) / 100 / 12; // Simplified: 4% APR monthly
        
        stakingRewards += rewards;
        emit StakingRewardsClaimed(rewards);
    }

    /**
     * @notice Get current runway in months
     * @return months Number of months of runway remaining
     */
    function getRunwayMonths() external view override returns (uint256 months) {
        uint256 totalStablecoins = stablecoinBalances[USDC] + 
                                  stablecoinBalances[USD1] + 
                                  stablecoinBalances[EURC];
        
        months = totalStablecoins / monthlyOpex;
    }

    /**
     * @notice Get current coverage ratio
     * @return ratio Coverage ratio (scaled by 1e18)
     */
    function getCoverageRatio() external view override returns (uint256 ratio) {
        if (outstandingATN == 0) return type(uint256).max;
        
        uint256 totalStablecoins = stablecoinBalances[USDC] + 
                                  stablecoinBalances[USD1] + 
                                  stablecoinBalances[EURC];
        
        uint256 ethValue = ((liquidETH + stakedETH + stakingRewards) * ethPrice) / 1e18;
        uint256 totalAssets = totalStablecoins + ethValue;
        
        ratio = (totalAssets * 1e18) / outstandingATN;
    }

    /**
     * @notice Get ETH holdings breakdown
     * @return liquid Liquid ETH balance
     * @return staked Staked ETH balance
     * @return rewards Accumulated staking rewards
     */
    function getETHBreakdown() external view override returns (uint256 liquid, uint256 staked, uint256 rewards) {
        return (liquidETH, stakedETH, stakingRewards);
    }

    /**
     * @notice Check if safety gates are green for buybacks
     * @return runwayOK True if runway >= 6 months
     * @return crOK True if coverage ratio >= 1.2x
     */
    function getSafetyGateStatus() public view override returns (bool runwayOK, bool crOK) {
        runwayOK = this.getRunwayMonths() >= minRunwayMonths;
        crOK = this.getCoverageRatio() >= minCoverageRatio;
    }

    /**
     * @notice Deposit stablecoins to treasury
     * @param asset Stablecoin address
     * @param amount Amount to deposit
     */
    function deposit(address asset, uint256 amount) external {
        require(_isSupportedAsset(asset), "Unsupported asset");
        
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        stablecoinBalances[asset] += amount;
    }

    /**
     * @notice Update outstanding ATN principal
     * @param amount New outstanding amount
     */
    function updateOutstandingATN(uint256 amount) external onlyOwner {
        outstandingATN = amount;
    }

    /**
     * @notice Update ETH price (in production use oracle)
     * @param newPrice New ETH price in USDC
     */
    function updateETHPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Invalid price");
        ethPrice = newPrice;
    }

    /**
     * @notice Update parameters
     */
    function updateMonthlyOpex(uint256 newOpex) external onlyOwner {
        monthlyOpex = newOpex;
        emit ParameterUpdated("monthlyOpex", newOpex);
    }

    function updateWeeklyDCACap(uint256 newCap) external onlyOwner {
        weeklyDCACap = newCap;
        emit ParameterUpdated("weeklyDCACap", newCap);
    }

    function updateFXArbThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold <= 100, "Threshold too high"); // Max 1%
        fxArbThreshold = newThreshold;
        emit ParameterUpdated("fxArbThreshold", newThreshold);
    }

    function updateETHStakingLimit(uint256 newLimit) external onlyOwner {
        require(newLimit <= 5000, "Limit too high"); // Max 50%
        ethStakingLimit = newLimit;
        emit ParameterUpdated("ethStakingLimit", newLimit);
    }

    /**
     * @notice Internal helper functions
     */
    function _isSupportedAsset(address asset) internal view returns (bool) {
        return asset == USDC || asset == USD1 || asset == EURC;
    }

    function _getImpliedFXRate(address fromAsset, address toAsset) internal pure returns (uint256) {
        // Simplified - in production use Chainlink oracles or DEX prices
        return 1e18; // Assume 1:1 for now
    }

    /**
     * @notice Emergency functions
     */
    function emergencyWithdraw(address asset, uint256 amount) external onlyOwner {
        IERC20(asset).safeTransfer(owner(), amount);
    }

    /**
     * @notice Receive ETH from DCA purchases or direct deposits
     */
    receive() external payable {
        liquidETH += msg.value;
    }

    /**
     * @notice Deposit ETH directly (for testing)
     */
    function depositETH() external payable {
        liquidETH += msg.value;
    }
}
