// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAttestationEmitter
 * @notice Interface for transparency event emissions
 */
interface IAttestationEmitter {
    /**
     * @notice Emit bond purchase event
     */
    function emitBondPurchased(
        address user,
        uint256 usdcAmount,
        uint256 agnAmount,
        uint256 timestamp
    ) external;

    /**
     * @notice Emit bond claim event
     */
    function emitBondClaimed(
        address user,
        uint256 bondId,
        uint256 amount,
        uint256 timestamp
    ) external;

    /**
     * @notice Emit staking deposit event
     */
    function emitStakingDeposit(
        address user,
        address asset,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    ) external;

    /**
     * @notice Emit staking withdraw event
     */
    function emitStakingWithdraw(
        address user,
        address asset,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    ) external;

    /**
     * @notice Emit harvest event
     */
    function emitHarvested(
        uint256 totalYield,
        uint256 totalFees,
        uint256 treasuryFees,
        uint256 boostBudget,
        uint256 timestamp
    ) external;

    /**
     * @notice Emit AGN lock event
     */
    function emitAGNLocked(
        address user,
        uint256 amount,
        uint256 lockDuration,
        uint256 timestamp
    ) external;

    /**
     * @notice Emit AGN unlock event
     */
    function emitAGNUnlocked(
        address user,
        uint256 amount,
        uint256 timestamp
    ) external;

    /**
     * @notice Emit buyback execution event
     */
    function emitBuybackExecuted(
        uint256 ethAmount,
        uint256 agnBought,
        uint256 agnBurned,
        uint256 agnToTreasury,
        uint256 timestamp
    ) external;
}
