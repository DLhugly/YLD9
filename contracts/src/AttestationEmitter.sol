// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AttestationEmitter
 * @notice Emits strategy performance and rebalancing events for full transparency
 * @dev Events-only contract for tracking protocol operations and performance metrics
 */
contract AttestationEmitter is Ownable {
    /// @notice Protocol addresses authorized to emit events
    mapping(address => bool) public authorizedEmitters;

    /// @notice Events for strategy performance tracking
    event StrategyPerformance(
        address indexed protocol,
        address indexed asset,
        uint256 tvl,
        uint256 apy,
        uint256 timestamp,
        bytes32 indexed strategyId
    );

    /// @notice Events for rebalancing operations
    event RebalanceExecuted(
        address indexed from,
        address indexed to,
        address indexed asset,
        uint256 amount,
        uint256 fromTVL,
        uint256 toTVL,
        uint256 timestamp,
        string reason
    );

    /// @notice Events for yield harvesting
    event YieldHarvested(
        address indexed protocol,
        address indexed asset,
        uint256 amount,
        uint256 fee,
        uint256 netYield,
        uint256 timestamp
    );

    /// @notice Events for FX arbitrage execution
    event FXArbitrageExecuted(
        address indexed fromAsset,
        address indexed toAsset,
        uint256 amountIn,
        uint256 amountOut,
        uint256 profit,
        uint256 timestamp,
        string venue
    );

    /// @notice Events for ETH DCA purchases
    event ETHPurchaseExecuted(
        address indexed asset,
        uint256 stablecoinAmount,
        uint256 ethAmount,
        uint256 price,
        uint256 timestamp,
        string venue
    );

    /// @notice Events for ETH staking operations
    event ETHStaked(
        address indexed stakingProvider,
        uint256 ethAmount,
        uint256 expectedRewards,
        uint256 timestamp
    );

    /// @notice Events for buyback operations
    event BuybackExecuted(
        uint256 usdcSpent,
        uint256 agnBought,
        uint256 agnBurned,
        uint256 agnToTreasury,
        uint256 avgPrice,
        uint256 timestamp
    );

    /// @notice Events for ATN bond operations
    event ATNSubscription(
        uint256 indexed trancheId,
        address indexed subscriber,
        uint256 amount,
        uint256 apr,
        uint256 maturityTime,
        uint256 timestamp
    );

    /// @notice Events for ATN coupon payments
    event ATNCouponPaid(
        uint256 indexed trancheId,
        address indexed holder,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice Events for safety gate status changes
    event SafetyGateStatusChanged(
        bool runwayOK,
        bool coverageRatioOK,
        uint256 runway,
        uint256 coverageRatio,
        uint256 timestamp
    );

    /// @notice Events for protocol parameter changes
    event ParameterUpdated(
        string indexed parameter,
        uint256 oldValue,
        uint256 newValue,
        address indexed updater,
        uint256 timestamp
    );

    /// @notice Events for governance proposals
    event GovernanceProposal(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        bool requiresLPApproval,
        uint256 timestamp
    );

    /// @notice Events for emergency actions
    event EmergencyAction(
        string indexed action,
        address indexed executor,
        string reason,
        uint256 timestamp
    );

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Add authorized emitter
     * @param emitter Address to authorize
     */
    function addAuthorizedEmitter(address emitter) external onlyOwner {
        require(emitter != address(0), "Invalid emitter");
        authorizedEmitters[emitter] = true;
    }

    /**
     * @notice Remove authorized emitter
     * @param emitter Address to remove
     */
    function removeAuthorizedEmitter(address emitter) external onlyOwner {
        authorizedEmitters[emitter] = false;
    }

    /**
     * @notice Modifier to check if caller is authorized
     */
    modifier onlyAuthorized() {
        require(authorizedEmitters[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    /**
     * @notice Emit strategy performance event
     */
    function emitStrategyPerformance(
        address protocol,
        address asset,
        uint256 tvl,
        uint256 apy,
        bytes32 strategyId
    ) external onlyAuthorized {
        emit StrategyPerformance(protocol, asset, tvl, apy, block.timestamp, strategyId);
    }

    /**
     * @notice Emit rebalance execution event
     */
    function emitRebalanceExecuted(
        address from,
        address to,
        address asset,
        uint256 amount,
        uint256 fromTVL,
        uint256 toTVL,
        string calldata reason
    ) external onlyAuthorized {
        emit RebalanceExecuted(from, to, asset, amount, fromTVL, toTVL, block.timestamp, reason);
    }

    /**
     * @notice Emit yield harvested event
     */
    function emitYieldHarvested(
        address protocol,
        address asset,
        uint256 amount,
        uint256 fee,
        uint256 netYield
    ) external onlyAuthorized {
        emit YieldHarvested(protocol, asset, amount, fee, netYield, block.timestamp);
    }

    /**
     * @notice Emit FX arbitrage execution event
     */
    function emitFXArbitrageExecuted(
        address fromAsset,
        address toAsset,
        uint256 amountIn,
        uint256 amountOut,
        uint256 profit,
        string calldata venue
    ) external onlyAuthorized {
        emit FXArbitrageExecuted(fromAsset, toAsset, amountIn, amountOut, profit, block.timestamp, venue);
    }

    /**
     * @notice Emit ETH purchase event
     */
    function emitETHPurchaseExecuted(
        address asset,
        uint256 stablecoinAmount,
        uint256 ethAmount,
        uint256 price,
        string calldata venue
    ) external onlyAuthorized {
        emit ETHPurchaseExecuted(asset, stablecoinAmount, ethAmount, price, block.timestamp, venue);
    }

    /**
     * @notice Emit ETH staking event
     */
    function emitETHStaked(
        address stakingProvider,
        uint256 ethAmount,
        uint256 expectedRewards
    ) external onlyAuthorized {
        emit ETHStaked(stakingProvider, ethAmount, expectedRewards, block.timestamp);
    }

    /**
     * @notice Emit buyback execution event
     */
    function emitBuybackExecuted(
        uint256 usdcSpent,
        uint256 agnBought,
        uint256 agnBurned,
        uint256 agnToTreasury,
        uint256 avgPrice
    ) external onlyAuthorized {
        emit BuybackExecuted(usdcSpent, agnBought, agnBurned, agnToTreasury, avgPrice, block.timestamp);
    }

    /**
     * @notice Emit ATN subscription event
     */
    function emitATNSubscription(
        uint256 trancheId,
        address subscriber,
        uint256 amount,
        uint256 apr,
        uint256 maturityTime
    ) external onlyAuthorized {
        emit ATNSubscription(trancheId, subscriber, amount, apr, maturityTime, block.timestamp);
    }

    /**
     * @notice Emit ATN coupon payment event
     */
    function emitATNCouponPaid(
        uint256 trancheId,
        address holder,
        uint256 amount
    ) external onlyAuthorized {
        emit ATNCouponPaid(trancheId, holder, amount, block.timestamp);
    }

    /**
     * @notice Emit safety gate status change event
     */
    function emitSafetyGateStatusChanged(
        bool runwayOK,
        bool coverageRatioOK,
        uint256 runway,
        uint256 coverageRatio
    ) external onlyAuthorized {
        emit SafetyGateStatusChanged(runwayOK, coverageRatioOK, runway, coverageRatio, block.timestamp);
    }

    /**
     * @notice Emit parameter update event
     */
    function emitParameterUpdated(
        string calldata parameter,
        uint256 oldValue,
        uint256 newValue,
        address updater
    ) external onlyAuthorized {
        emit ParameterUpdated(parameter, oldValue, newValue, updater, block.timestamp);
    }

    /**
     * @notice Emit governance proposal event
     */
    function emitGovernanceProposal(
        uint256 proposalId,
        address proposer,
        string calldata title,
        bool requiresLPApproval
    ) external onlyAuthorized {
        emit GovernanceProposal(proposalId, proposer, title, requiresLPApproval, block.timestamp);
    }

    /**
     * @notice Emit emergency action event
     */
    function emitEmergencyAction(
        string calldata action,
        address executor,
        string calldata reason
    ) external onlyAuthorized {
        emit EmergencyAction(action, executor, reason, block.timestamp);
    }

    /**
     * @notice Get all authorized emitters (helper function)
     * @dev This is a simplified version - in production might want enumerable functionality
     */
    function isAuthorizedEmitter(address emitter) external view returns (bool) {
        return authorizedEmitters[emitter];
    }
}
