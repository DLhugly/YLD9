// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITreasury.sol";
import "./Buyback.sol";
import "./BondManager.sol";
import "./TreasuryManager.sol";
import "./AttestationEmitter.sol";

/**
 * @title KeeperRegistry
 * @notice Gelato automation registry for weekly Agonic operations
 * @dev Manages automated DCA, buybacks, coupon payments, rebalancing, and TPT publishing
 */
contract KeeperRegistry is Ownable, ReentrancyGuard {

    /// @notice Contract addresses
    ITreasury public treasury;
    Buyback public buyback;
    BondManager public bondManager;
    TreasuryManager public treasuryManager;
    AttestationEmitter public attestationEmitter;
    
    /// @notice Keeper operation intervals
    uint256 public constant WEEKLY_INTERVAL = 1 weeks;
    uint256 public constant DAILY_INTERVAL = 1 days;
    uint256 public constant REBALANCE_INTERVAL = 4 hours;
    
    /// @notice Last execution timestamps
    uint256 public lastWeeklyDCA;
    uint256 public lastBuyback;
    uint256 public lastCouponPayment;
    uint256 public lastRebalancing;
    uint256 public lastTPTPublish;
    uint256 public lastFXArbitrage;
    
    /// @notice Gas price limits (wei)
    uint256 public maxGasPrice = 100 gwei;
    
    /// @notice Daily/weekly spend caps
    uint256 public dailyFXCap = 50000e6; // $50K USDC max FX arbitrage per day
    uint256 public weeklyDCACap = 5000e6; // $5K USDC weekly DCA
    
    /// @notice Daily FX arbitrage tracking
    mapping(uint256 => uint256) public dailyFXSpent; // day => amount spent
    
    /// @notice Circuit breakers
    mapping(string => bool) public functionPaused;
    
    /// @notice Authorized keepers (Gelato addresses)
    mapping(address => bool) public authorizedKeepers;
    
    /// @notice Keeper execution tracking
    struct KeeperExecution {
        string functionName;
        address keeper;
        uint256 timestamp;
        bool success;
        string failureReason;
        uint256 gasUsed;
    }
    
    /// @notice Execution history
    KeeperExecution[] public executionHistory;
    
    /// @notice Events
    event KeeperExecuted(string functionName, address keeper, bool success, uint256 gasUsed);
    event FunctionPaused(string functionName, bool paused);
    event KeeperAuthorized(address keeper, bool authorized);
    event ParameterUpdated(string param, uint256 value);
    event DryRunCompleted(string functionName, bool wouldSucceed, string reason);

    modifier onlyKeeper() {
        require(authorizedKeepers[msg.sender] || msg.sender == owner(), "Not authorized keeper");
        _;
    }

    modifier notPaused(string memory functionName) {
        require(!functionPaused[functionName], "Function is paused");
        _;
    }

    modifier gasCheck() {
        require(tx.gasprice <= maxGasPrice, "Gas price too high");
        _;
    }

    constructor(
        address _treasury,
        address _buyback,
        address _bondManager,
        address _treasuryManager,
        address _attestationEmitter
    ) Ownable(msg.sender) {
        treasury = ITreasury(_treasury);
        buyback = Buyback(_buyback);
        bondManager = BondManager(_bondManager);
        treasuryManager = TreasuryManager(_treasuryManager);
        attestationEmitter = AttestationEmitter(_attestationEmitter);
        
        // Initialize timestamps
        lastWeeklyDCA = block.timestamp;
        lastBuyback = block.timestamp;
        lastCouponPayment = block.timestamp;
        lastRebalancing = block.timestamp;
        lastTPTPublish = block.timestamp;
        lastFXArbitrage = block.timestamp;
    }

    /**
     * @notice Execute weekly DCA (Monday 00:00 UTC)
     * @dev Keeper function with safety checks
     */
    function executeWeeklyDCA() 
        external 
        onlyKeeper 
        nonReentrant 
        notPaused("weeklyDCA") 
        gasCheck 
    {
        require(block.timestamp >= lastWeeklyDCA + WEEKLY_INTERVAL, "Too early for DCA");
        
        uint256 gasStart = gasleft();
        bool success = false;
        string memory failureReason = "";
        
        try treasury.weeklyDCA() {
            success = true;
            lastWeeklyDCA = block.timestamp;
        } catch Error(string memory reason) {
            failureReason = reason;
        } catch {
            failureReason = "Unknown error";
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Record execution
        _recordExecution("weeklyDCA", msg.sender, success, failureReason, gasUsed);
        
        emit KeeperExecuted("weeklyDCA", msg.sender, success, gasUsed);
    }

    /**
     * @notice Execute weekly buyback (Monday 12:00 UTC)
     * @dev Keeper function with safety gate checks
     */
    function executeWeeklyBuyback() 
        external 
        onlyKeeper 
        nonReentrant 
        notPaused("buyback") 
        gasCheck 
    {
        require(block.timestamp >= lastBuyback + WEEKLY_INTERVAL, "Too early for buyback");
        
        uint256 gasStart = gasleft();
        bool success = false;
        string memory failureReason = "";
        
        try buyback.executeBuyback() {
            success = true;
            lastBuyback = block.timestamp;
        } catch Error(string memory reason) {
            failureReason = reason;
        } catch {
            failureReason = "Unknown error";
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Record execution
        _recordExecution("buyback", msg.sender, success, failureReason, gasUsed);
        
        emit KeeperExecuted("buyback", msg.sender, success, gasUsed);
    }

    /**
     * @notice Pay weekly ATN coupons (Sunday 23:00 UTC)
     * @dev Keeper function for all active tranches
     */
    function payWeeklyCoupons() 
        external 
        onlyKeeper 
        nonReentrant 
        notPaused("coupons") 
        gasCheck 
    {
        require(block.timestamp >= lastCouponPayment + WEEKLY_INTERVAL, "Too early for coupons");
        
        uint256 gasStart = gasleft();
        bool success = false;
        string memory failureReason = "";
        
        try bondManager.payAllCoupons() {
            success = true;
            lastCouponPayment = block.timestamp;
        } catch Error(string memory reason) {
            failureReason = reason;
        } catch {
            failureReason = "Unknown error";
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Record execution
        _recordExecution("coupons", msg.sender, success, failureReason, gasUsed);
        
        emit KeeperExecuted("coupons", msg.sender, success, gasUsed);
    }

    /**
     * @notice Execute rebalancing when conditions are met
     * @dev Check APY deviation > 2% or allocation drift > 5%
     */
    function executeRebalancing() 
        external 
        onlyKeeper 
        nonReentrant 
        notPaused("rebalancing") 
        gasCheck 
    {
        require(block.timestamp >= lastRebalancing + REBALANCE_INTERVAL, "Too frequent rebalancing");
        
        uint256 gasStart = gasleft();
        bool success = false;
        string memory failureReason = "";
        
        // Check if rebalancing is needed
        if (_shouldRebalance()) {
            try treasuryManager.executeRebalancing() {
                success = true;
                lastRebalancing = block.timestamp;
            } catch Error(string memory reason) {
                failureReason = reason;
            } catch {
                failureReason = "Unknown error";
            }
        } else {
            failureReason = "Rebalancing not needed";
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Record execution
        _recordExecution("rebalancing", msg.sender, success, failureReason, gasUsed);
        
        emit KeeperExecuted("rebalancing", msg.sender, success, gasUsed);
    }

    /**
     * @notice Execute FX arbitrage when price deviation > 0.1%
     * @dev Respects daily volume cap
     */
    function executeFXArbitrage(address fromAsset, address toAsset, uint256 amount) 
        external 
        onlyKeeper 
        nonReentrant 
        notPaused("fxArbitrage") 
        gasCheck 
    {
        require(amount > 0, "Invalid amount");
        
        // Check daily cap
        uint256 today = block.timestamp / 1 days;
        require(dailyFXSpent[today] + amount <= dailyFXCap, "Daily FX cap exceeded");
        
        uint256 gasStart = gasleft();
        bool success = false;
        string memory failureReason = "";
        
        try treasury.executeFXArbitrage(fromAsset, toAsset, amount) {
            success = true;
            dailyFXSpent[today] += amount;
            lastFXArbitrage = block.timestamp;
        } catch Error(string memory reason) {
            failureReason = reason;
        } catch {
            failureReason = "Unknown error";
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Record execution
        _recordExecution("fxArbitrage", msg.sender, success, failureReason, gasUsed);
        
        emit KeeperExecuted("fxArbitrage", msg.sender, success, gasUsed);
    }

    /**
     * @notice Publish weekly TPT metric (Sunday 22:00 UTC)
     * @dev Keeper function for transparency
     */
    function publishWeeklyTPT() 
        external 
        onlyKeeper 
        nonReentrant 
        notPaused("tptPublish") 
        gasCheck 
    {
        require(block.timestamp >= lastTPTPublish + WEEKLY_INTERVAL, "Too early for TPT");
        
        uint256 gasStart = gasleft();
        bool success = false;
        string memory failureReason = "";
        
        try treasury.publishTPT() {
            success = true;
            lastTPTPublish = block.timestamp;
        } catch Error(string memory reason) {
            failureReason = reason;
        } catch {
            failureReason = "Unknown error";
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Record execution
        _recordExecution("tptPublish", msg.sender, success, failureReason, gasUsed);
        
        emit KeeperExecuted("tptPublish", msg.sender, success, gasUsed);
    }

    /**
     * @notice Dry run any keeper function to check if it would succeed
     * @param functionName Function to simulate
     * @return wouldSucceed Whether the function would succeed
     * @return reason Failure reason if applicable
     */
    function dryRun(string calldata functionName) 
        external 
        view 
        returns (bool wouldSucceed, string memory reason) 
    {
        bytes32 funcHash = keccak256(bytes(functionName));
        
        if (funcHash == keccak256(bytes("weeklyDCA"))) {
            if (block.timestamp < lastWeeklyDCA + WEEKLY_INTERVAL) {
                return (false, "Too early for DCA");
            }
            (bool runwayOK, bool crOK) = treasury.getSafetyGateStatus();
            if (!runwayOK) return (false, "Runway < 6 months");
            if (!crOK) return (false, "Coverage ratio < 1.2x");
            return (true, "");
            
        } else if (funcHash == keccak256(bytes("buyback"))) {
            if (block.timestamp < lastBuyback + WEEKLY_INTERVAL) {
                return (false, "Too early for buyback");
            }
            (bool canExecute,,,) = buyback.getSafetyGateStatus();
            if (!canExecute) return (false, "Safety gates not green");
            return (true, "");
            
        } else if (funcHash == keccak256(bytes("coupons"))) {
            if (block.timestamp < lastCouponPayment + WEEKLY_INTERVAL) {
                return (false, "Too early for coupons");
            }
            (bool runwayOK, bool crOK) = treasury.getSafetyGateStatus();
            if (!crOK) return (false, "CR < 1.2x, coupons paused");
            return (true, "");
            
        } else if (funcHash == keccak256(bytes("rebalancing"))) {
            if (block.timestamp < lastRebalancing + REBALANCE_INTERVAL) {
                return (false, "Too frequent");
            }
            if (!_shouldRebalance()) return (false, "Rebalancing not needed");
            return (true, "");
            
        } else if (funcHash == keccak256(bytes("tptPublish"))) {
            if (block.timestamp < lastTPTPublish + WEEKLY_INTERVAL) {
                return (false, "Too early for TPT");
            }
            return (true, "");
        }
        
        return (false, "Unknown function");
    }

    /**
     * @notice Check if rebalancing should be executed
     * @return shouldRebalance Whether rebalancing is needed
     */
    function _shouldRebalance() internal view returns (bool shouldRebalance) {
        // In production: check actual APY deviations and allocation drift
        // For mock: assume rebalancing needed every 24 hours
        shouldRebalance = block.timestamp >= lastRebalancing + DAILY_INTERVAL;
    }

    /**
     * @notice Record keeper execution in history
     */
    function _recordExecution(
        string memory functionName,
        address keeper,
        bool success,
        string memory failureReason,
        uint256 gasUsed
    ) internal {
        executionHistory.push(KeeperExecution({
            functionName: functionName,
            keeper: keeper,
            timestamp: block.timestamp,
            success: success,
            failureReason: failureReason,
            gasUsed: gasUsed
        }));
    }

    /**
     * @notice Get keeper execution statistics
     * @return stats Execution statistics
     */
    function getKeeperStats() external view returns (KeeperStats memory stats) {
        uint256 totalExecutions = executionHistory.length;
        uint256 successfulExecutions = 0;
        uint256 totalGasUsed = 0;
        
        for (uint256 i = 0; i < totalExecutions; i++) {
            if (executionHistory[i].success) {
                successfulExecutions++;
            }
            totalGasUsed += executionHistory[i].gasUsed;
        }
        
        stats = KeeperStats({
            totalExecutions: totalExecutions,
            successfulExecutions: successfulExecutions,
            successRate: totalExecutions > 0 ? (successfulExecutions * 10000) / totalExecutions : 0,
            avgGasUsed: totalExecutions > 0 ? totalGasUsed / totalExecutions : 0,
            lastWeeklyDCA: lastWeeklyDCA,
            lastBuyback: lastBuyback,
            lastCouponPayment: lastCouponPayment,
            lastTPTPublish: lastTPTPublish
        });
    }

    /**
     * @notice Get recent execution history
     * @param count Number of recent executions to return
     * @return executions Array of recent executions
     */
    function getRecentExecutions(uint256 count) external view returns (KeeperExecution[] memory executions) {
        uint256 historyLength = executionHistory.length;
        uint256 returnCount = count > historyLength ? historyLength : count;
        
        executions = new KeeperExecution[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            executions[i] = executionHistory[historyLength - 1 - i];
        }
    }

    /**
     * @notice Authorize/deauthorize keeper (owner only)
     * @param keeper Keeper address
     * @param authorized Authorization status
     */
    function setKeeperAuthorization(address keeper, bool authorized) external onlyOwner {
        authorizedKeepers[keeper] = authorized;
        emit KeeperAuthorized(keeper, authorized);
    }

    /**
     * @notice Pause/unpause specific function (owner only)
     * @param functionName Function to pause/unpause
     * @param paused Pause status
     */
    function setFunctionPaused(string calldata functionName, bool paused) external onlyOwner {
        functionPaused[functionName] = paused;
        emit FunctionPaused(functionName, paused);
    }

    /**
     * @notice Update gas price limit (owner only)
     * @param newLimit New gas price limit in wei
     */
    function updateGasPriceLimit(uint256 newLimit) external onlyOwner {
        require(newLimit >= 10 gwei && newLimit <= 500 gwei, "Invalid gas price limit");
        maxGasPrice = newLimit;
        emit ParameterUpdated("maxGasPrice", newLimit);
    }

    /**
     * @notice Update daily FX arbitrage cap (owner only)
     * @param newCap New daily cap in USDC
     */
    function updateDailyFXCap(uint256 newCap) external onlyOwner {
        require(newCap <= 200000e6, "Cap too high"); // Max $200K/day
        dailyFXCap = newCap;
        emit ParameterUpdated("dailyFXCap", newCap);
    }

    /**
     * @notice Emergency pause all functions (owner only)
     */
    function emergencyPauseAll() external onlyOwner {
        functionPaused["weeklyDCA"] = true;
        functionPaused["buyback"] = true;
        functionPaused["coupons"] = true;
        functionPaused["rebalancing"] = true;
        functionPaused["fxArbitrage"] = true;
        functionPaused["tptPublish"] = true;
        
        emit FunctionPaused("ALL", true);
    }

    /**
     * @notice Resume all functions (owner only)
     */
    function resumeAll() external onlyOwner {
        functionPaused["weeklyDCA"] = false;
        functionPaused["buyback"] = false;
        functionPaused["coupons"] = false;
        functionPaused["rebalancing"] = false;
        functionPaused["fxArbitrage"] = false;
        functionPaused["tptPublish"] = false;
        
        emit FunctionPaused("ALL", false);
    }

    /**
     * @notice Keeper statistics struct
     */
    struct KeeperStats {
        uint256 totalExecutions;
        uint256 successfulExecutions;
        uint256 successRate; // basis points
        uint256 avgGasUsed;
        uint256 lastWeeklyDCA;
        uint256 lastBuyback;
        uint256 lastCouponPayment;
        uint256 lastTPTPublish;
    }
}
