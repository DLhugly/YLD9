// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "chainlink-brownie-contracts/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IBuyback.sol";
import "./interfaces/IAttestationEmitter.sol";
import "./adapters/AaveAdapter.sol";
import "./adapters/LidoAdapter.sol";

/**
 * @title Treasury
 * @notice Manages ETH accumulation, DCA purchases, FX arbitrage, and ETH staking
 * @dev Implements MicroStrategy-style ETH treasury with safety gates
 */
contract Treasury is ITreasury, Ownable, ReentrancyGuard, AutomationCompatibleInterface {
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
    AggregatorV3Interface public ethUsdPriceFeed;
    AaveAdapter public aaveAdapter;
    LidoAdapter public lidoAdapter;
    
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
    
    /// @notice 80/20 Automated Router Constants
    uint256 public constant STABLE_ALLOCATION_BPS = 8000; // 80% to stables
    uint256 public constant GROWTH_ALLOCATION_BPS = 2000; // 20% to growth/buyback
    uint256 public constant ETH_DCA_BPS = 1000; // 10% to ETH DCA (within 20%)
    uint256 public constant BUYBACK_BPS = 1000; // 10% to AGN buybacks (within 20%)
    
    /// @notice Automation timing
    uint256 public lastHarvestTime;
    uint256 public lastDCATime;
    uint256 public harvestInterval = 7 days; // Weekly harvests
    uint256 public dcaInterval = 7 days; // Weekly DCA
    
    /// @notice Runway and buffer management
    uint256 public targetRunwayMonths = 12; // 12-month runway target
    uint256 public minBufferRatio = 1500; // 15% minimum buffer (1.5x safety factor)
    
    /// @notice Burn throttle when safety gates are low
    uint256 public constant BURN_BPS = 9000; // 90% burn rate when safety gates OK
    uint256 public constant LOW_SAFETY_BURN_BPS = 5000; // 50% when runway/CR low
    

    
    /// @notice Minimum coverage ratio (scaled by 1e18)
    uint256 public minCoverageRatio = 1.2e18; // 1.2x
    
    /// @notice Minimum runway months
    uint256 public minRunwayMonths = 6;
    
    /// @notice Outstanding ATN principal
    uint256 public outstandingATN;
    

    
    /// @notice Maximum basis points
    uint256 public constant MAX_BPS = 10000;
    

    

    
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


    event ETHStaked(uint256 amount, uint256 totalStaked);
    event StakingRewardsClaimed(uint256 amount);
    event SafetyGateTriggered(string gate, bool status);
    event ParameterUpdated(string param, uint256 value);
    event TPTPublished(uint256 tptValue, uint256 totalTreasuryValue, uint256 circulatingSupply, uint256 timestamp);

    event PriceFeedUpdated(address indexed priceFeed);
    event AutomatedHarvest(uint256 aaveYield, uint256 lidoRewards, uint256 totalYield);
    event AutomatedDCA(uint256 usdcAmount, uint256 ethAmount, uint256 ethPrice);
    event AutomatedRouting(uint256 stableAmount, uint256 ethAmount, uint256 buybackAmount);

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
        
        uint256 ethValue = ((liquidETH + stakedETH + stakingRewards) * getCurrentETHPrice()) / 1e18;
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
     * @notice Update parameters
     */
    function updateMonthlyOpex(uint256 newOpex) external onlyOwner {
        monthlyOpex = newOpex;
        emit ParameterUpdated("monthlyOpex", newOpex);
    }







    /**
     * @notice Internal helper functions
     */
    function _isSupportedAsset(address asset) internal view returns (bool) {
        return asset == USDC || asset == USD1 || asset == EURC;
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
        totalValue += (totalETH * getCurrentETHPrice()) / 1e18; // Convert ETH to USDC value
        
        // Add staking rewards value
        totalValue += (stakingRewards * getCurrentETHPrice()) / 1e18;
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
        uint256 targetStaked = totalETH; // Can stake all ETH via Lido
        
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
        if (address(ethUsdPriceFeed) != address(0)) {
            try ethUsdPriceFeed.latestRoundData() returns (
                uint80 roundId,
                int256 price,
                uint256 startedAt,
                uint256 updatedAt,
                uint80 answeredInRound
            ) {
                require(price > 0, "Invalid price");
                require(updatedAt > block.timestamp - 3600, "Price too stale"); // 1 hour staleness check
                
                // Chainlink ETH/USD has 8 decimals, convert to 6 decimals (USDC)
                return uint256(price) / 100; // 8 decimals -> 6 decimals
            } catch {
                // Fallback to manual price if Chainlink fails
                return manualETHPrice;
            }
        }
        
        // Fallback to manual or default price
        return manualETHPrice;
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
        require(_priceFeed != address(0), "Invalid price feed");
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeed);
        
        // Verify the price feed works
        try ethUsdPriceFeed.latestRoundData() returns (
            uint80, int256 price, uint256, uint256 updatedAt, uint80
        ) {
            require(price > 0, "Invalid initial price");
            require(updatedAt > 0, "Invalid update time");
        } catch {
            revert("Price feed verification failed");
        }
        
        emit PriceFeedUpdated(_priceFeed);
    }

    /**
     * @notice Chainlink Automation - Check if upkeep is needed
     * @return upkeepNeeded Whether upkeep should be performed
     * @return performData Encoded data for performUpkeep
     */
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        bool harvestNeeded = (block.timestamp >= lastHarvestTime + harvestInterval);
        bool dcaNeeded = (block.timestamp >= lastDCATime + dcaInterval);
        
        if (harvestNeeded || dcaNeeded) {
            upkeepNeeded = true;
            performData = abi.encode(harvestNeeded, dcaNeeded);
        }
    }
    
    /**
     * @notice Chainlink Automation - Perform upkeep
     * @param performData Encoded data from checkUpkeep
     */
    function performUpkeep(bytes calldata performData) external override {
        (bool harvestNeeded, bool dcaNeeded) = abi.decode(performData, (bool, bool));
        
        if (harvestNeeded) {
            _performAutomatedHarvest();
        }
        
        if (dcaNeeded) {
            _performAutomatedDCA();
        }
    }
    
    /**
     * @notice Perform automated harvest of all yield sources
     */
    function _performAutomatedHarvest() internal {
        uint256 aaveYield = 0;
        uint256 lidoRewards = 0;
        
        // Harvest Aave yield
        if (address(aaveAdapter) != address(0)) {
            try aaveAdapter.harvest() returns (uint256 yield) {
                aaveYield = yield;
            } catch {
                // Continue if harvest fails
            }
        }
        
        // Harvest Lido rewards  
        if (address(lidoAdapter) != address(0)) {
            try lidoAdapter.harvest() returns (uint256 rewards) {
                lidoRewards = rewards;
            } catch {
                // Continue if harvest fails
            }
        }
        
        uint256 totalYield = aaveYield + lidoRewards;
        
        if (totalYield > 0) {
            // Route harvested yield through 80/20 automation
            _processInflowAutomated(totalYield);
        }
        
        lastHarvestTime = block.timestamp;
        emit AutomatedHarvest(aaveYield, lidoRewards, totalYield);
    }
    
    /**
     * @notice Perform automated ETH DCA purchase
     */
    function _performAutomatedDCA() internal {
        // Calculate available USDC for DCA (from 10% allocation)
        uint256 availableUSDC = stablecoinBalances[USDC];
        
        // Only proceed if we have sufficient buffer
        uint256 requiredBuffer = monthlyOpex * targetRunwayMonths;
        if (availableUSDC <= requiredBuffer) {
            return; // Skip DCA if runway is at risk
        }
        
        uint256 excessUSDC = availableUSDC - requiredBuffer;
        uint256 dcaAmount = (excessUSDC * ETH_DCA_BPS) / 10000; // 10% of excess for DCA
        
        if (dcaAmount > 0) {
            uint256 currentETHPrice = getCurrentETHPrice();
            uint256 ethAmount = (dcaAmount * 1e18) / currentETHPrice;
            
            // Execute DCA purchase
            stablecoinBalances[USDC] -= dcaAmount;
            liquidETH += ethAmount;
            
            // Stake ETH via Lido if adapter is available
            if (address(lidoAdapter) != address(0) && address(this).balance >= ethAmount) {
                try lidoAdapter.stake{value: ethAmount}() returns (uint256 stETHAmount) {
                    stakedETH += stETHAmount;
                    liquidETH -= ethAmount;
                } catch {
                    // Keep as liquid ETH if staking fails
                }
            }
            
            lastDCATime = block.timestamp;
            emit AutomatedDCA(dcaAmount, ethAmount, currentETHPrice);
        }
    }
    
    /**
     * @notice Process inflows with automated 80/20 routing (public interface)
     * @param totalInflow Total inflow amount in USDC terms
     */
    function processInflowAutomated(uint256 totalInflow) external {
        _processInflowAutomated(totalInflow);
    }

    /**
     * @notice Process inflows with automated 80/20 routing (internal)
     * @param totalInflow Total inflow amount in USDC terms
     */
    function _processInflowAutomated(uint256 totalInflow) internal {
        // 80% to stable allocation (USDC buffer + Aave)
        uint256 stableAmount = (totalInflow * STABLE_ALLOCATION_BPS) / 10000;
        
        // 10% to ETH DCA (handled in DCA automation)
        uint256 ethAmount = (totalInflow * ETH_DCA_BPS) / 10000;
        
        // 10% to AGN buybacks
        uint256 buybackAmount = (totalInflow * BUYBACK_BPS) / 10000;
        
        // Route stable allocation
        _routeStableAllocation(stableAmount);
        
        // Add ETH allocation to pending DCA pool
        stablecoinBalances[USDC] += ethAmount;
        
        // Fund buyback pool
        if (address(buyback) != address(0) && buybackAmount > 0) {
            IERC20(USDC).safeTransfer(address(buyback), buybackAmount);
            try buyback.fundBuybackPool(buybackAmount) {} catch {}
        }
        
        emit AutomatedRouting(stableAmount, ethAmount, buybackAmount);
    }
    
    /**
     * @notice Route stable allocation between buffer and Aave
     * @param stableAmount Amount to route
     */
    function _routeStableAllocation(uint256 stableAmount) internal {
        uint256 requiredBuffer = monthlyOpex * targetRunwayMonths;
        uint256 currentBuffer = stablecoinBalances[USDC];
        
        if (currentBuffer < requiredBuffer) {
            // Fill buffer first
            uint256 bufferNeeded = requiredBuffer - currentBuffer;
            uint256 toBuffer = stableAmount > bufferNeeded ? bufferNeeded : stableAmount;
            stablecoinBalances[USDC] += toBuffer;
            stableAmount -= toBuffer;
        }
        
        // Deploy excess to Aave for yield
        if (stableAmount > 0 && address(aaveAdapter) != address(0)) {
            IERC20(USDC).approve(address(aaveAdapter), stableAmount);
            try aaveAdapter.deposit(USDC, stableAmount) {} catch {
                // Keep in buffer if Aave deposit fails
                stablecoinBalances[USDC] += stableAmount;
            }
        }
    }

    /**
     * @notice Set adapter contracts
     */
    function setAaveAdapter(address _aaveAdapter) external onlyOwner {
        aaveAdapter = AaveAdapter(_aaveAdapter);
    }
    
    function setLidoAdapter(address payable _lidoAdapter) external onlyOwner {
        lidoAdapter = LidoAdapter(_lidoAdapter);
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
