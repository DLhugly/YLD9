// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITreasury.sol";

/**
 * @title LPStaking
 * @notice LP staking rewards for Aerodrome AGN/USDC pool
 * @dev Treasury-funded AGN emissions (no minting), per-pool caps, weekly budget control
 */
contract LPStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Aerodrome AGN/USDC LP token
    IERC20 public immutable lpToken;
    
    /// @notice AGN reward token
    IERC20 public immutable AGN;
    
    /// @notice Treasury contract (source of AGN rewards)
    ITreasury public treasury;
    
    /// @notice Weekly AGN emission budget from treasury (no minting)
    uint256 public weeklyBudget = 1000e18; // 1000 AGN per week
    
    /// @notice Pool TVL cap (in LP token units)
    uint256 public poolCap = 500000e18; // $500K equivalent
    
    /// @notice Per-user staking cap (in LP token units)
    uint256 public userCap = 50000e18; // $50K equivalent
    
    /// @notice Reward rate per second (updated weekly)
    uint256 public rewardRate;
    
    /// @notice Last reward update timestamp
    uint256 public lastUpdateTime;
    
    /// @notice Accumulated reward per token stored
    uint256 public rewardPerTokenStored;
    
    /// @notice Total LP tokens staked
    uint256 public totalSupply;
    
    /// @notice User balances
    mapping(address => uint256) public balanceOf;
    
    /// @notice User reward per token paid
    mapping(address => uint256) public userRewardPerTokenPaid;
    
    /// @notice User pending rewards
    mapping(address => uint256) public rewards;
    
    /// @notice Emergency pause state
    bool public paused;
    
    /// @notice Weekly emission tracking
    struct WeeklyEmission {
        uint256 week;
        uint256 budgetUsed;
        uint256 actualEmitted;
        uint256 participantCount;
        uint256 avgTVL;
    }
    
    /// @notice Weekly emission history
    mapping(uint256 => WeeklyEmission) public weeklyEmissions;
    uint256 public currentWeek;
    
    /// @notice Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event BudgetUpdated(uint256 newBudget);
    event RewardRateUpdated(uint256 newRate);
    event EmergencyPause(bool paused);
    event WeeklyBudgetSet(uint256 week, uint256 budget);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(
        address _lpToken,
        address _agn,
        address _treasury
    ) Ownable(msg.sender) {
        lpToken = IERC20(_lpToken);
        AGN = IERC20(_agn);
        treasury = ITreasury(_treasury);
        lastUpdateTime = block.timestamp;
        currentWeek = block.timestamp / 1 weeks;
    }

    /**
     * @notice Stake LP tokens to earn AGN rewards
     * @param amount LP token amount to stake
     */
    function stake(uint256 amount) external nonReentrant notPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        require(totalSupply + amount <= poolCap, "Pool cap exceeded");
        require(balanceOf[msg.sender] + amount <= userCap, "User cap exceeded");
        
        // Transfer LP tokens from user
        lpToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update balances
        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        
        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Withdraw staked LP tokens
     * @param amount LP token amount to withdraw
     */
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        // Update balances
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        
        // Transfer LP tokens to user
        lpToken.safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Claim earned AGN rewards
     */
    function getReward() public nonReentrant notPaused updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            
            // Request AGN from treasury (no minting)
            treasury.transferAGNForRewards(msg.sender, reward);
            
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @notice Exit: withdraw all LP tokens and claim rewards
     */
    function exit() external {
        withdraw(balanceOf[msg.sender]);
        getReward();
    }

    /**
     * @notice Calculate reward per token
     * @return Accumulated reward per token
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        
        return rewardPerTokenStored + 
            (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalSupply);
    }

    /**
     * @notice Calculate earned rewards for account
     * @param account User address
     * @return Earned reward amount
     */
    function earned(address account) public view returns (uint256) {
        return (balanceOf[account] * 
            (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) + 
            rewards[account];
    }

    /**
     * @notice Set weekly AGN emission budget (owner only)
     * @param budget Weekly AGN budget from treasury
     */
    function setWeeklyBudget(uint256 budget) external onlyOwner {
        require(budget <= 5000e18, "Budget too high"); // Max 5K AGN/week
        
        uint256 week = block.timestamp / 1 weeks;
        weeklyBudget = budget;
        
        // Update reward rate for current week
        rewardRate = budget / 1 weeks;
        lastUpdateTime = block.timestamp;
        
        // Record weekly budget
        weeklyEmissions[week] = WeeklyEmission({
            week: week,
            budgetUsed: budget,
            actualEmitted: 0,
            participantCount: 0,
            avgTVL: totalSupply
        });
        
        emit BudgetUpdated(budget);
        emit RewardRateUpdated(rewardRate);
        emit WeeklyBudgetSet(week, budget);
    }

    /**
     * @notice Update pool and user caps (owner only)
     * @param newPoolCap New pool TVL cap
     * @param newUserCap New per-user cap
     */
    function updateCaps(uint256 newPoolCap, uint256 newUserCap) external onlyOwner {
        require(newPoolCap >= totalSupply, "Pool cap below current TVL");
        require(newUserCap > 0, "Invalid user cap");
        
        poolCap = newPoolCap;
        userCap = newUserCap;
    }

    /**
     * @notice Emergency pause/unpause (owner only)
     * @param _paused Pause state
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit EmergencyPause(_paused);
    }

    /**
     * @notice Emergency withdraw all LP tokens (when paused)
     */
    function emergencyWithdraw() external nonReentrant {
        require(paused, "Not in emergency mode");
        
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "No balance to withdraw");
        
        // Update balances without reward calculation
        totalSupply -= amount;
        balanceOf[msg.sender] = 0;
        
        // Transfer LP tokens
        lpToken.safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Get staking statistics
     * @return stats Current staking statistics
     */
    function getStakingStats() external view returns (StakingStats memory stats) {
        uint256 currentAPY = totalSupply > 0 ? 
            (rewardRate * 365 days * 1e18) / totalSupply : 0;
            
        stats = StakingStats({
            totalStaked: totalSupply,
            totalParticipants: _getParticipantCount(),
            currentAPY: currentAPY,
            weeklyBudget: weeklyBudget,
            poolUtilization: (totalSupply * 10000) / poolCap, // basis points
            rewardRate: rewardRate,
            nextBudgetReset: ((block.timestamp / 1 weeks) + 1) * 1 weeks
        });
    }

    /**
     * @notice Get user staking info
     * @param user User address
     * @return info User staking information
     */
    function getUserInfo(address user) external view returns (UserInfo memory info) {
        info = UserInfo({
            stakedBalance: balanceOf[user],
            pendingRewards: earned(user),
            userCapRemaining: userCap - balanceOf[user],
            canStakeMore: balanceOf[user] < userCap && totalSupply < poolCap
        });
    }

    /**
     * @notice Count active participants (addresses with non-zero balance)
     * @return count Number of active stakers
     */
    function _getParticipantCount() internal view returns (uint256 count) {
        // In production: maintain a counter or use events
        // For now, return estimated count based on average stake
        if (totalSupply > 0) {
            count = totalSupply / 1000e18; // Estimate: avg 1K LP per user
            if (count == 0) count = 1;
        }
    }

    /**
     * @notice Update treasury contract (owner only)
     * @param newTreasury New treasury address
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = ITreasury(newTreasury);
    }

    /**
     * @notice Staking statistics struct
     */
    struct StakingStats {
        uint256 totalStaked;
        uint256 totalParticipants;
        uint256 currentAPY;
        uint256 weeklyBudget;
        uint256 poolUtilization; // basis points
        uint256 rewardRate;
        uint256 nextBudgetReset;
    }

    /**
     * @notice User information struct
     */
    struct UserInfo {
        uint256 stakedBalance;
        uint256 pendingRewards;
        uint256 userCapRemaining;
        bool canStakeMore;
    }
}
