// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IBuyback
 * @notice Interface for the Buyback contract
 */
interface IBuyback {
    /**
     * @notice Execute buyback with ETH amount
     * @param ethAmount Amount of ETH to use for buyback
     * @return agnBought Amount of AGN purchased
     */
    function executeBuyback(uint256 ethAmount) external returns (uint256 agnBought);

    /**
     * @notice Get current AGN price
     * @return price Current AGN price in ETH
     */
    function getCurrentAGNPrice() external view returns (uint256 price);

    /**
     * @notice Check if buyback can be executed
     * @param ethAmount Amount of ETH for buyback
     * @return canExecute Whether buyback can be executed
     */
    function canExecuteBuyback(uint256 ethAmount) external view returns (bool canExecute);
    
    /**
     * @notice Fund buyback pool with USDC
     * @param amount Amount of USDC to add to buyback pool
     */
    function fundBuybackPool(uint256 amount) external;
}
