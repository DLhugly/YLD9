// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LidoAdapter
 * @notice Simple adapter for ETH staking via Lido
 * @dev Provides liquid staking for ETH treasury
 */
contract LidoAdapter is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Lido stETH token address (would be Base equivalent)
    address public constant STETH = 0x0000000000000000000000000000000000000000; // Placeholder
    
    /// @notice Current staked ETH balance
    uint256 public stakedBalance;
    
    /// @notice Accumulated staking rewards
    uint256 public accumulatedRewards;

    /// @notice Events
    event ETHStaked(uint256 amount, uint256 stETHReceived);
    event ETHUnstaked(uint256 amount, uint256 ethReceived);
    event RewardsHarvested(uint256 amount);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Stake ETH and receive stETH
     * @return stETHAmount Amount of stETH received
     */
    function stake() external payable returns (uint256 stETHAmount) {
        require(msg.value > 0, "Must stake ETH");
        
        // In production: call actual Lido contract
        // For now, simulate 1:1 conversion
        stETHAmount = msg.value;
        stakedBalance += msg.value;
        
        emit ETHStaked(msg.value, stETHAmount);
    }

    /**
     * @notice Unstake stETH to receive ETH
     * @param amount Amount of stETH to unstake
     * @return ethAmount Amount of ETH received
     */
    function unstake(uint256 amount) external onlyOwner returns (uint256 ethAmount) {
        require(amount <= stakedBalance, "Insufficient staked balance");
        
        // In production: call actual Lido unstaking
        // For now, simulate 1:1 conversion
        ethAmount = amount;
        stakedBalance -= amount;
        
        // Transfer ETH back to caller
        payable(msg.sender).transfer(ethAmount);
        
        emit ETHUnstaked(amount, ethAmount);
    }

    /**
     * @notice Harvest staking rewards
     * @return rewardAmount Amount of rewards harvested
     */
    function harvest() external onlyOwner returns (uint256 rewardAmount) {
        // In production: calculate actual Lido rewards
        // For now, simulate 4% APR
        rewardAmount = (stakedBalance * 4) / 100 / 365; // Daily reward approximation
        
        if (rewardAmount > 0) {
            accumulatedRewards += rewardAmount;
            
            // In production: claim actual rewards from Lido
            // For now, just track internally
            
            emit RewardsHarvested(rewardAmount);
        }
    }

    /**
     * @notice Get current APY
     * @return apy Current staking APY (basis points)
     */
    function getCurrentAPY() external pure returns (uint256 apy) {
        return 400; // 4% APY
    }

    /**
     * @notice Get total staked balance including rewards
     * @return totalBalance Total balance (staked + rewards)
     */
    function getBalance() external view returns (uint256 totalBalance) {
        return stakedBalance + accumulatedRewards;
    }

    /**
     * @notice Emergency withdrawal
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner()).transfer(balance);
        }
    }

    /**
     * @notice Receive ETH
     */
    receive() external payable {
        // Accept ETH for staking operations
    }
}
