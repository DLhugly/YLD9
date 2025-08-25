// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITreasuryManager
 * @notice Interface for the TreasuryManager contract that handles multi-protocol integrations
 */
interface ITreasuryManager {
    /**
     * @notice Harvest yield from all integrated protocols
     * @return totalYield Total yield harvested across all protocols
     */
    function harvestAll() external returns (uint256 totalYield);

    /**
     * @notice Rebalance assets across protocols
     * @param requiredIdle Minimum idle buffer to maintain
     */
    function rebalance(uint256 requiredIdle) external;

    /**
     * @notice Rebalance to prepare for a specific asset withdrawal
     * @param asset Asset to prepare for withdrawal
     * @param amount Amount needed for withdrawal
     */
    function rebalanceForWithdrawal(address asset, uint256 amount) external;

    /**
     * @notice Get total assets deployed across all protocols
     * @return Total deployed assets in USD terms
     */
    function getTotalDeployed() external view returns (uint256);

    /**
     * @notice Emergency withdraw all funds from protocols
     */
    function emergencyWithdraw() external;

    /**
     * @notice Get allocation breakdown across protocols
     * @return protocols Array of protocol addresses
     * @return allocations Array of allocation amounts
     */
    function getAllocationBreakdown() external view returns (address[] memory protocols, uint256[] memory allocations);
}
