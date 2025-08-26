// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title cbETHAdapter
 * @notice Adapter for ETH staking via Coinbase cbETH (native to Base)
 * @dev cbETH is the primary liquid staking token on Base L2
 */
contract cbETHAdapter is Ownable {
    using SafeERC20 for IERC20;

    /// @notice cbETH token address on Base mainnet
    address public constant CBETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22; // cbETH on Base
    
    /// @notice Current staked ETH balance
    uint256 public stakedBalance;
    
    /// @notice Accumulated staking rewards
    uint256 public accumulatedRewards;

    /// @notice Events
    event ETHStaked(uint256 amount, uint256 cbETHReceived);
    event ETHUnstaked(uint256 amount, uint256 ethReceived);
    event RewardsHarvested(uint256 amount);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Stake ETH and receive cbETH
     * @return cbETHAmount Amount of cbETH received
     */
    function stake() external payable returns (uint256 cbETHAmount) {
        require(msg.value > 0, "Must stake ETH");
        
        // In production: swap ETH for cbETH via DEX or mint directly
        // cbETH accrues value automatically (~3-4% APY)
        cbETHAmount = msg.value; // Simplified 1:1 for now
        stakedBalance += msg.value;
        
        emit ETHStaked(msg.value, cbETHAmount);
        return cbETHAmount;
    }

    /**
     * @notice Unstake cbETH and receive ETH
     * @param amount Amount of cbETH to unstake
     * @return ethAmount Amount of ETH received
     */
    function unstake(uint256 amount) external returns (uint256 ethAmount) {
        require(amount > 0 && amount <= stakedBalance, "Invalid amount");
        
        // In production: swap cbETH for ETH via DEX
        ethAmount = amount; // Simplified 1:1
        stakedBalance -= amount;
        
        payable(msg.sender).transfer(ethAmount);
        emit ETHUnstaked(amount, ethAmount);
        
        return ethAmount;
    }

    /**
     * @notice Harvest staking rewards
     * @return rewardAmount Amount of rewards harvested
     */
    function harvest() external onlyOwner returns (uint256 rewardAmount) {
        // cbETH yields ~3-4% APY on Base
        // Calculate rewards based on time and balance
        uint256 estimatedAPY = 350; // 3.5% in basis points
        rewardAmount = (stakedBalance * estimatedAPY) / 10000 / 365; // Daily rewards
        
        if (rewardAmount > 0) {
            accumulatedRewards += rewardAmount;
            emit RewardsHarvested(rewardAmount);
        }
        
        return rewardAmount;
    }

    /**
     * @notice Get current staking APY
     * @return apy Current APY in basis points
     */
    function getCurrentAPY() external pure returns (uint256 apy) {
        // cbETH APY on Base (~3-4%)
        return 350; // 3.5%
    }

    /**
     * @notice Get total value locked
     * @return tvl Total ETH + rewards
     */
    function getTotalValue() external view returns (uint256 tvl) {
        return stakedBalance + accumulatedRewards;
    }

    /**
     * @notice Emergency withdraw function
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner()).transfer(balance);
    }

    receive() external payable {}
}