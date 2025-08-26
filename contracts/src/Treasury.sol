// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; // TODO: Add Chainlink dependency
import "./interfaces/ITreasury.sol";
import "./interfaces/IBuyback.sol";
import "./interfaces/IAttestationEmitter.sol";

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
    address public immutable AGN;
    
    /// @notice External contracts
    IBuyback public buyback;
    IAttestationEmitter public attestationEmitter;
    // AggregatorV3Interface public ethUsdPriceFeed; // TODO: Add Chainlink dependency
    
    /// @notice Manual ETH price (fallback)
    uint256 public manualETHPrice;
    uint256 public lastPriceUpdate;

    /// @notice Stablecoin balances
    mapping(address => uint256) public stablecoinBalances;
    
    /// @notice ETH balances
    uint256 public liquidETH;
    uint256 public stakedETH;
    uint256 public stakingRewards;
    
    /// @notice Monthly operational expenses in USDC
    uint256 public monthlyOpex = 50000e6; // $50k USDC
    
    /// @notice Auto-buyback split (80% burn, 20% treasury)
    uint256 public constant BURN_BPS = 8000; // 80%
    uint256 public constant TREASURY_BPS = 2000; // 20%
    
    /// @notice Burn throttle when safety gates are low
    uint256 public constant LOW_SAFETY_BURN_BPS = 5000; // 50% when runway/CR low
    
    /// @notice ETH staking allocation limit (basis points)
    uint256 public ethStakingLimit = 10000; // 100% can be staked via Lido
    
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
    
    /// @notice Weekly DCA cap in USDC
    uint256 public weeklyDCACap = 5000e6; // $5k USDC
    
    /// @notice FX arbitrage threshold (basis points)
    uint256 public fxArbThreshold = 10; // 0.1%
    
    /// @notice TPT (Treasury per Token) history
    struct TPTSnapshot {
        uint256 timestamp;
        uint256 tptValue; // Treasury value per AGN token (scaled by 1e18)
        uint256 totalTreasuryValue; // Total treasury value in USDC
        uint256 circulatingSupply; // AGN circulating supply
    }
    
    /// @notice TPT snapshots array
    TPTSnapshot[] public tptHistory;
    
    /// @notice Last TPT publish timestamp
    uint256 public lastTPTPublish;
    
    /// @notice Events
    event DCAPurchase(uint256 usdcAmount, uint256 ethAmount, uint256 ethPrice);
    event FXArbitrage(address fromAsset, address toAsset, uint256 amount, uint256 profit);
    event ETHStaked(uint256 amount, uint256 totalStaked);
    event StakingRewardsClaimed(uint256 amount);
    event SafetyGateTriggered(string gate, bool status);
    event ParameterUpdated(string param, uint256 value);
    event TPTPublished(uint256 tptValue, uint256 totalTreasuryValue, uint256 circulatingSupply, uint256 timestamp);
    event InflowProcessed(uint256 usdcAmount, uint256 ethAmount, uint256 buybackAmount, uint256 holdAmount);

        constructor(
        address _usdc,
        address _usd1, 
        address _eurc,
        address _weth,
        address _agn
    ) Ownable(msg.sender) {
        USDC = _usdc;
        USD1 = _usd1;
        EURC = _eurc;
        WETH = _weth;
        AGN = _agn;
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
     * @notice Process inflow from bonds/staking fees with auto-buyback (ultra-simple)
     * @param usdcAmount Amount of USDC received
     */
    function processInflow(uint256 usdcAmount) external nonReentrant {
        require(usdcAmount > 0, "Amount must be > 0");
        
        // Convert USDC to ETH
        uint256 ethAmount = _swapUSDCToETH(usdcAmount);
        
        // Determine burn ratio based on safety gates
        uint256 burnRatio = _getBurnRatio();
        
        // Split: burn ratio for buybacks, remainder held as ETH
        uint256 buybackAmount = (ethAmount * burnRatio) / 10000;
        uint256 holdAmount = ethAmount - buybackAmount;
        
        // Execute buyback if amount > 0
        if (buybackAmount > 0 && address(buyback) != address(0)) {
            // Transfer ETH to buyback contract and execute
            payable(address(buyback)).transfer(buybackAmount);
            buyback.executeBuyback(buybackAmount);
        }
        
        // Hold remaining ETH in treasury (stake via Lido if configured)
        if (holdAmount > 0) {
            liquidETH += holdAmount;
            _stakeETHIfNeeded();
        }
        
        // Update TPT and emit events
        _updateTPT();
        
        emit InflowProcessed(usdcAmount, ethAmount, buybackAmount, holdAmount);
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
     * @notice Set AGN token address (owner only)
     * @param _agn AGN token address
     */
    function setAGNToken(address _agn) external onlyOwner {
        require(_agn != address(0), "Invalid AGN address");
        AGN = _agn;
    }

    /**
     * @notice Calculate current TPT (Treasury per Token) value
     * @return tptValue TPT in USDC per AGN (scaled by 1e18)
     * @return totalValue Total treasury value in USDC
     * @return supply Circulating AGN supply
     */
    function calculateTPT() public view returns (
        uint256 tptValue,
        uint256 totalValue,
        uint256 supply
    ) {
        // Calculate total treasury value
        totalValue = getTotalTreasuryValue();
        
        // Get circulating AGN supply
        supply = getCirculatingSupply();
        
        // Calculate TPT
        if (supply > 0) {
            tptValue = (totalValue * 1e18) / supply;
        }
    }

    /**
     * @notice Publish weekly TPT metric
     * @dev Called by keeper or owner weekly
     */
    function publishTPT() external {
        require(
            block.timestamp >= lastTPTPublish + 1 weeks || msg.sender == owner(),
            "Too early for TPT publish"
        );
        
        (uint256 tptValue, uint256 totalValue, uint256 supply) = calculateTPT();
        
        // Record snapshot
        tptHistory.push(TPTSnapshot({
            timestamp: block.timestamp,
            tptValue: tptValue,
            totalTreasuryValue: totalValue,
            circulatingSupply: supply
        }));
        
        lastTPTPublish = block.timestamp;
        
        emit TPTPublished(tptValue, totalValue, supply, block.timestamp);
    }

    /**
     * @notice Get total treasury value in USDC
     * @return totalValue Total value including stablecoins and ETH
     */
    function getTotalTreasuryValue() public view returns (uint256 totalValue) {
        // Add all stablecoin balances
        totalValue += stablecoinBalances[USDC];
        totalValue += stablecoinBalances[USD1];
        totalValue += stablecoinBalances[EURC];
        
        // Add ETH value (liquid + staked)
        uint256 totalETH = liquidETH + stakedETH;
        totalValue += (totalETH * ethPrice) / 1e18; // Convert ETH to USDC value
        
        // Add staking rewards value
        totalValue += (stakingRewards * ethPrice) / 1e18;
    }

    /**
     * @notice Get circulating AGN supply
     * @return supply Circulating supply (total - treasury holdings)
     */
    function getCirculatingSupply() public view returns (uint256 supply) {
        if (address(AGN) != address(0)) {
            uint256 totalSupply = IERC20(AGN).totalSupply();
            uint256 treasuryBalance = IERC20(AGN).balanceOf(address(this));
            supply = totalSupply - treasuryBalance;
        }
    }

    /**
     * @notice Get TPT history
     * @param count Number of recent snapshots to return
     * @return snapshots Array of TPT snapshots
     */
    function getTPTHistory(uint256 count) external view returns (TPTSnapshot[] memory snapshots) {
        uint256 historyLength = tptHistory.length;
        uint256 returnCount = count > historyLength ? historyLength : count;
        
        snapshots = new TPTSnapshot[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            snapshots[i] = tptHistory[historyLength - 1 - i];
        }
    }

    /**
     * @notice Get latest TPT value
     * @return tptValue Most recent TPT value
     * @return timestamp When it was recorded
     */
    function getLatestTPT() external view returns (uint256 tptValue, uint256 timestamp) {
        if (tptHistory.length > 0) {
            TPTSnapshot memory latest = tptHistory[tptHistory.length - 1];
            tptValue = latest.tptValue;
            timestamp = latest.timestamp;
        }
    }

    /**
     * @notice Transfer AGN for LP staking rewards (called by LPStaking contract)
     * @param to Recipient address
     * @param amount AGN amount to transfer
     */
    function transferAGNForRewards(address to, uint256 amount) external {
        require(msg.sender == owner() || _isAuthorizedContract(msg.sender), "Unauthorized");
        require(address(AGN) != address(0), "AGN not set");
        
        IERC20(AGN).safeTransfer(to, amount);
    }

    /**
     * @notice Check if contract is authorized to call treasury functions
     * @param contractAddr Contract address to check
     * @return authorized Whether contract is authorized
     */
    function _isAuthorizedContract(address contractAddr) internal pure returns (bool authorized) {
        // In production: maintain whitelist of authorized contracts
        // For now, allow any contract (will be restricted in deployment)
        authorized = true;
    }

    /**
     * @notice Convert USDC to ETH (simplified)
     */
    function _swapUSDCToETH(uint256 usdcAmount) internal returns (uint256 ethAmount) {
        uint256 currentPrice = getCurrentETHPrice();
        ethAmount = (usdcAmount * 1e18) / currentPrice;
        stablecoinBalances[USDC] += usdcAmount;
    }

    /**
     * @notice Get burn ratio based on safety gates
     */
    function _getBurnRatio() internal view returns (uint256 burnRatio) {
        (bool runwayOK, bool crOK) = getSafetyGateStatus();
        return (runwayOK && crOK) ? BURN_BPS : LOW_SAFETY_BURN_BPS;
    }

    /**
     * @notice Stake ETH via Lido if needed
     */
    function _stakeETHIfNeeded() internal {
        uint256 totalETH = liquidETH + stakedETH;
        uint256 targetStaked = (totalETH * ethStakingLimit) / 10000;
        
        if (liquidETH > 0 && stakedETH < targetStaked) {
            uint256 toStake = liquidETH;
            if (stakedETH + toStake > targetStaked) {
                toStake = targetStaked - stakedETH;
            }
            
            if (toStake > 0) {
                liquidETH -= toStake;
                stakedETH += toStake;
            }
        }
    }

    /**
     * @notice Update TPT metric
     */
    function _updateTPT() internal {
        uint256 totalTreasuryValue = getTotalTreasuryValue();
        uint256 circulatingSupply = getCirculatingSupply();
        
        if (circulatingSupply > 0) {
            uint256 tptValue = (totalTreasuryValue * 1e18) / circulatingSupply;
            
            tptHistory.push(TPTSnapshot({
                tptValue: tptValue,
                totalTreasuryValue: totalTreasuryValue,
                circulatingSupply: circulatingSupply,
                timestamp: block.timestamp
            }));
            
            emit TPTPublished(tptValue, totalTreasuryValue, circulatingSupply, block.timestamp);
        }
    }

    /**
     * @notice Get current ETH price
     */
    function getCurrentETHPrice() public view returns (uint256) {
        return ethPrice;
    }

    /**
     * @notice Get AGN price for bond calculations
     */
    function getAGNPrice() external view returns (uint256 price) {
        return 1e18; // $1.00 per AGN (simplified)
    }



    /**
     * @notice Set external contracts
     */
    function setBuyback(address _buyback) external onlyOwner {
        buyback = IBuyback(_buyback);
    }

    function setAttestationEmitter(address _attestationEmitter) external onlyOwner {
        attestationEmitter = IAttestationEmitter(_attestationEmitter);
    }

    function setETHPriceFeed(address _priceFeed) external onlyOwner {
        // ethUsdPriceFeed = AggregatorV3Interface(_priceFeed); // TODO: Add Chainlink dependency
        manualETHPrice = 2000e6; // Temporary fallback price
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
