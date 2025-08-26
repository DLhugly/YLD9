// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IAttestationEmitter.sol";
import "./adapters/AaveAdapter.sol";
import "./adapters/LidoAdapter.sol";

/**
 * @title StakingVault
 * @notice ERC-4626 compatible vault for USDC/ETH staking with AGN boosts
 * @dev Fixed Aave for USDC, Lido for ETH, 5% fee, +5% boost for AGN lockers
 */
contract StakingVault is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============
    
    uint256 public constant FEE_BPS = 500;        // 5% fee on yields
    uint256 public constant BOOST_BPS = 500;      // +5% boost for AGN lockers
    uint256 public constant BOOST_BUDGET_BPS = 2000; // 20% of fees for boosts
    uint256 public constant MIN_LOCK_DURATION = 30 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;

    // ============ Immutables ============
    
    IERC20 public immutable USDC;
    IERC20 public immutable WETH;
    IERC20 public immutable AGN;
    ITreasury public immutable treasury;
    IAttestationEmitter public immutable attestationEmitter;
    AaveAdapter public immutable aaveAdapter;
    LidoAdapter public immutable lidoAdapter;

    // ============ State Variables ============
    
    struct AssetInfo {
        uint256 totalDeposited;    // Total deposited in this asset
        uint256 totalYield;        // Total yield earned
        uint256 lastHarvest;       // Last harvest timestamp
    }

    struct UserLock {
        uint256 amount;            // Locked AGN amount
        uint256 lockStart;         // Lock start timestamp
        uint256 lockEnd;           // Lock end timestamp
        uint256 boostEarned;       // Total boost earned
    }

    mapping(address => AssetInfo) public assetInfo; // asset => info
    mapping(address => UserLock) public userLocks;  // user => lock info
    mapping(address => mapping(address => uint256)) public userAssetShares; // user => asset => shares

    uint256 public totalShares;
    uint256 public lastHarvestTime;
    uint256 public totalFeesCollected;
    uint256 public totalBoostsPaid;
    
    bool public paused;

    // ============ Events ============
    
    event Deposited(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Harvested(address indexed asset, uint256 yield, uint256 fees, uint256 boosts);
    event AGNLocked(address indexed user, uint256 amount, uint256 lockEnd);
    event AGNUnlocked(address indexed user, uint256 amount);
    event BoostPaid(address indexed user, uint256 amount);

    // ============ Constructor ============
    
    constructor(
        address _usdc,
        address _weth,
        address _agn,
        address _treasury,
        address _attestationEmitter,
        address _aaveAdapter,
        address payable _lidoAdapter
    ) ERC20("Agonic Staking Vault", "aSTAKE") Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC");
        require(_weth != address(0), "Invalid WETH");
        require(_agn != address(0), "Invalid AGN");
        require(_treasury != address(0), "Invalid treasury");
        require(_attestationEmitter != address(0), "Invalid attestation emitter");
        require(_aaveAdapter != address(0), "Invalid Aave adapter");
        require(_lidoAdapter != address(0), "Invalid Lido adapter");

        USDC = IERC20(_usdc);
        WETH = IERC20(_weth);
        AGN = IERC20(_agn);
        treasury = ITreasury(_treasury);
        attestationEmitter = IAttestationEmitter(_attestationEmitter);
        aaveAdapter = AaveAdapter(_aaveAdapter);
        lidoAdapter = LidoAdapter(_lidoAdapter);
        
        lastHarvestTime = block.timestamp;
    }

    // ============ Main Functions ============

    /**
     * @notice Deposit USDC or WETH for staking
     * @param assetAddress Address of asset to deposit (USDC or WETH)
     * @param amount Amount to deposit
     * @return shares Amount of shares minted
     */
    function deposit(address assetAddress, uint256 amount) external nonReentrant returns (uint256 shares) {
        require(!paused, "Vault paused");
        require(assetAddress == address(USDC) || assetAddress == address(WETH), "Unsupported asset");
        require(amount > 0, "Amount must be > 0");

        // Transfer asset from user
        IERC20(assetAddress).safeTransferFrom(msg.sender, address(this), amount);

        // Calculate shares (1:1 for simplicity, can be enhanced later)
        shares = amount;

        // Deploy to yield strategies
        if (assetAddress == address(USDC)) {
            // Approve and deposit to Aave
            USDC.approve(address(aaveAdapter), amount);
            aaveAdapter.deposit(assetAddress, amount);
        } else {
            // Stake ETH via Lido
            lidoAdapter.stake{value: amount}();
        }

        // Update state
        assetInfo[assetAddress].totalDeposited += amount;
        userAssetShares[msg.sender][assetAddress] += shares;
        totalShares += shares;

        // Mint vault shares
        _mint(msg.sender, shares);

        emit Deposited(msg.sender, assetAddress, amount, shares);
        
        attestationEmitter.emitStakingDeposit(
            msg.sender,
            assetAddress,
            amount,
            shares,
            block.timestamp
        );
    }

    /**
     * @notice Withdraw staked assets
     * @param assetAddress Address of asset to withdraw
     * @param shares Amount of shares to burn
     * @return amount Amount of asset withdrawn
     */
    function withdraw(address assetAddress, uint256 shares) external nonReentrant returns (uint256 amount) {
        require(shares > 0, "Shares must be > 0");
        require(userAssetShares[msg.sender][assetAddress] >= shares, "Insufficient shares");

        // Calculate withdrawal amount (1:1 for simplicity)
        amount = shares;

        // Withdraw from yield strategies
        if (assetAddress == address(USDC)) {
            aaveAdapter.withdraw(assetAddress, amount);
        } else {
            lidoAdapter.unstake(amount);
        }

        // Update state
        assetInfo[assetAddress].totalDeposited -= amount;
        userAssetShares[msg.sender][assetAddress] -= shares;
        totalShares -= shares;

        // Burn vault shares
        _burn(msg.sender, shares);

        // Transfer asset to user
        IERC20(assetAddress).safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, assetAddress, amount, shares);
        
        attestationEmitter.emitStakingWithdraw(
            msg.sender,
            assetAddress,
            amount,
            shares,
            block.timestamp
        );
    }

    /**
     * @notice Harvest yields from all strategies
     * @return totalYield Total yield harvested across all assets
     */
    function harvest() external nonReentrant returns (uint256 totalYield) {
        require(block.timestamp >= lastHarvestTime + 1 days, "Too soon to harvest");

        uint256 usdcYield = aaveAdapter.harvest();
        uint256 ethYield = lidoAdapter.harvest();
        
        totalYield = usdcYield + ethYield;
        require(totalYield > 0, "No yield to harvest");

        // Calculate fees (5% of total yield)
        uint256 totalFees = (totalYield * FEE_BPS) / 10000;
        uint256 boostBudget = (totalFees * BOOST_BUDGET_BPS) / 10000; // 20% of fees
        uint256 treasuryFees = totalFees - boostBudget;

        // Update state
        lastHarvestTime = block.timestamp;
        totalFeesCollected += totalFees;
        
        if (usdcYield > 0) {
            assetInfo[address(USDC)].totalYield += usdcYield;
            assetInfo[address(USDC)].lastHarvest = block.timestamp;
        }
        
        if (ethYield > 0) {
            assetInfo[address(WETH)].totalYield += ethYield;
            assetInfo[address(WETH)].lastHarvest = block.timestamp;
        }

        // Send fees to treasury for buybacks
        if (treasuryFees > 0) {
            // Convert all fees to USDC for simplicity
            uint256 usdcFees = _convertToUSDC(treasuryFees, usdcYield, ethYield);
            USDC.safeTransfer(address(treasury), usdcFees);
            treasury.processInflow(usdcFees);
        }

        // Distribute boosts to AGN lockers
        if (boostBudget > 0) {
            _distributeBoosts(boostBudget);
        }

        emit Harvested(address(0), totalYield, totalFees, boostBudget);
        
        attestationEmitter.emitHarvested(
            totalYield,
            totalFees,
            treasuryFees,
            boostBudget,
            block.timestamp
        );
    }

    /**
     * @notice Lock AGN tokens to earn yield boosts
     * @param amount Amount of AGN to lock
     * @param lockDuration Duration to lock (30-365 days)
     */
    function lockAGN(uint256 amount, uint256 lockDuration) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(lockDuration >= MIN_LOCK_DURATION && lockDuration <= MAX_LOCK_DURATION, "Invalid duration");
        require(userLocks[msg.sender].amount == 0, "Already have active lock");

        // Transfer AGN from user
        AGN.safeTransferFrom(msg.sender, address(this), amount);

        // Create lock
        userLocks[msg.sender] = UserLock({
            amount: amount,
            lockStart: block.timestamp,
            lockEnd: block.timestamp + lockDuration,
            boostEarned: 0
        });

        emit AGNLocked(msg.sender, amount, block.timestamp + lockDuration);
        
        attestationEmitter.emitAGNLocked(
            msg.sender,
            amount,
            lockDuration,
            block.timestamp
        );
    }

    /**
     * @notice Unlock AGN tokens after lock period
     */
    function unlockAGN() external nonReentrant {
        UserLock storage lock = userLocks[msg.sender];
        require(lock.amount > 0, "No active lock");
        require(block.timestamp >= lock.lockEnd, "Lock not expired");

        uint256 amount = lock.amount;
        
        // Clear lock
        delete userLocks[msg.sender];

        // Transfer AGN back to user
        AGN.safeTransfer(msg.sender, amount);

        emit AGNUnlocked(msg.sender, amount);
        
        attestationEmitter.emitAGNUnlocked(
            msg.sender,
            amount,
            block.timestamp
        );
    }

    // ============ View Functions ============

    /**
     * @notice Get user's boost multiplier
     */
    function getBoostMultiplier(address user) public view returns (uint256) {
        UserLock storage lock = userLocks[user];
        if (lock.amount > 0 && block.timestamp < lock.lockEnd) {
            return 10000 + BOOST_BPS; // +5%
        }
        return 10000; // No boost
    }

    /**
     * @notice Get user's effective yield rate for an asset
     */
    function getUserYieldRate(address user, address assetAddress) external view returns (uint256) {
        uint256 baseRate = getAssetYieldRate(assetAddress);
        uint256 multiplier = getBoostMultiplier(user);
        return (baseRate * multiplier) / 10000;
    }

    /**
     * @notice Get base yield rate for an asset
     */
    function getAssetYieldRate(address assetAddress) public view returns (uint256) {
        if (assetAddress == address(USDC)) {
            return aaveAdapter.getCurrentAPY(assetAddress);
        } else if (assetAddress == address(WETH)) {
            return lidoAdapter.getCurrentAPY();
        }
        return 0;
    }

    /**
     * @notice Get user's total staked amount across all assets
     */
    function getUserTotalStaked(address user) external view returns (uint256 total) {
        total += userAssetShares[user][address(USDC)];
        total += userAssetShares[user][address(WETH)];
    }

    /**
     * @notice Get vault TVL across all assets
     */
    function getTotalValueLocked() external view returns (uint256 tvl) {
        tvl += assetInfo[address(USDC)].totalDeposited;
        tvl += assetInfo[address(WETH)].totalDeposited;
    }

    // ============ Internal Functions ============

    function _convertToUSDC(uint256 totalFees, uint256 usdcYield, uint256 ethYield) internal pure returns (uint256) {
        // Simplified: assume proportional conversion based on yield amounts
        if (usdcYield + ethYield == 0) return 0;
        
        uint256 usdcPortion = (totalFees * usdcYield) / (usdcYield + ethYield);
        uint256 ethPortion = totalFees - usdcPortion;
        
        // For ETH portion, would need price oracle to convert to USDC
        // For simplicity, assume 1:1 conversion (would need proper implementation)
        return usdcPortion + ethPortion;
    }

    function _distributeBoosts(uint256 boostBudget) internal {
        // Simplified boost distribution
        // In practice, would distribute proportionally to locked amounts and durations
        totalBoostsPaid += boostBudget;
        
        // For now, just track the budget
        // Real implementation would iterate through all lockers
    }

    // ============ Admin Functions ============

    /**
     * @notice Emergency pause/unpause vault
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    /**
     * @notice Emergency withdrawal of assets (only if paused)
     */
    function emergencyWithdraw(address assetAddress) external onlyOwner {
        require(paused, "Not paused");
        uint256 balance = IERC20(assetAddress).balanceOf(address(this));
        if (balance > 0) {
            IERC20(assetAddress).safeTransfer(owner(), balance);
        }
    }

    // ============ ERC-4626 Compatibility ============

    function asset() public view returns (address) {
        return address(USDC); // Primary asset
    }

    function totalAssets() public view returns (uint256) {
        return assetInfo[address(USDC)].totalDeposited;
    }

    function convertToShares(uint256 assets) public pure returns (uint256) {
        return assets; // 1:1 for simplicity
    }

    function convertToAssets(uint256 shares) public pure returns (uint256) {
        return shares; // 1:1 for simplicity
    }

    function maxDeposit(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return userAssetShares[owner][address(USDC)];
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(uint256 assets) public pure returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public pure returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(uint256 assets) public pure returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) public pure returns (uint256) {
        return convertToAssets(shares);
    }
}
