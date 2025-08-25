// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITreasury
 * @notice Interface for the Treasury contract that handles ETH accumulation and DCA
 */
interface ITreasury {
    /**
     * @notice Execute weekly DCA purchase of ETH
     * @param amount Amount of stablecoins to convert to ETH
     * @return ethPurchased Amount of ETH purchased
     */
    function weeklyDCA(uint256 amount) external returns (uint256 ethPurchased);

    /**
     * @notice Execute FX arbitrage across stablecoin pairs
     * @param fromAsset Source stablecoin
     * @param toAsset Target stablecoin
     * @param amount Amount to arbitrage
     * @return profit Profit from arbitrage
     */
    function executeFXArbitrage(address fromAsset, address toAsset, uint256 amount) external returns (uint256 profit);

    /**
     * @notice Stake portion of ETH holdings
     * @param amount Amount of ETH to stake
     * @return stakedAmount Amount actually staked
     */
    function stakeETH(uint256 amount) external returns (uint256 stakedAmount);

    /**
     * @notice Get current runway in months
     * @return months Number of months of runway remaining
     */
    function getRunwayMonths() external view returns (uint256 months);

    /**
     * @notice Get current coverage ratio
     * @return ratio Coverage ratio (scaled by 1e18)
     */
    function getCoverageRatio() external view returns (uint256 ratio);

    /**
     * @notice Get ETH holdings breakdown
     * @return liquid Liquid ETH balance
     * @return staked Staked ETH balance
     * @return rewards Accumulated staking rewards
     */
    function getETHBreakdown() external view returns (uint256 liquid, uint256 staked, uint256 rewards);

    /**
     * @notice Check if safety gates are green for buybacks
     * @return runwayOK True if runway >= 6 months
     * @return crOK True if coverage ratio >= 1.2x
     */
    function getSafetyGateStatus() external view returns (bool runwayOK, bool crOK);

    /**
     * @notice Deposit stablecoins to treasury
     * @param asset Stablecoin address
     * @param amount Amount to deposit
     */
    function deposit(address asset, uint256 amount) external;

    /**
     * @notice Update outstanding ATN principal
     * @param amount New outstanding amount
     */
    function updateOutstandingATN(uint256 amount) external;

    /**
     * @notice Transfer AGN for LP staking rewards
     * @param to Recipient address
     * @param amount AGN amount to transfer
     */
    function transferAGNForRewards(address to, uint256 amount) external;

    /**
     * @notice Calculate current TPT (Treasury per Token) value
     * @return tptValue TPT in USDC per AGN (scaled by 1e18)
     * @return totalValue Total treasury value in USDC
     * @return supply Circulating AGN supply
     */
    function calculateTPT() external view returns (uint256 tptValue, uint256 totalValue, uint256 supply);

    /**
     * @notice Publish weekly TPT metric
     */
    function publishTPT() external;

    /**
     * @notice Get total treasury value in USDC
     * @return totalValue Total value including stablecoins and ETH
     */
    function getTotalTreasuryValue() external view returns (uint256 totalValue);
}
