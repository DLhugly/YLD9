// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ATNTranche
 * @notice Individual ATN (Agonic Treasury Note) tranche implementation
 * @dev Non-transferable until maturity, represents fixed-APR notes
 */
contract ATNTranche is ERC20, Ownable {
    /// @notice Underlying stablecoin asset
    address public immutable asset;
    
    /// @notice BondManager contract (only authorized minter/burner)
    address public immutable bondManager;
    
    /// @notice Whether transfers are enabled (only after maturity)
    bool public transfersEnabled;
    
    /// @notice Tranche launch timestamp
    uint256 public immutable launchTime;
    
    /// @notice Events
    event TransfersEnabled();
    event NoteMinted(address indexed to, uint256 amount);
    event NoteBurned(address indexed from, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        address _asset,
        address _bondManager
    ) ERC20(name, symbol) Ownable(_bondManager) {
        asset = _asset;
        bondManager = _bondManager;
        launchTime = block.timestamp;
        transfersEnabled = false;
    }

    /**
     * @notice Mint ATN tokens (only BondManager)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        
        _mint(to, amount);
        emit NoteMinted(to, amount);
    }

    /**
     * @notice Burn ATN tokens (only BondManager)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external onlyOwner {
        require(from != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(balanceOf(from) >= amount, "Insufficient balance");
        
        _burn(from, amount);
        emit NoteBurned(from, amount);
    }

    /**
     * @notice Enable transfers after maturity
     */
    function enableTransfers() external onlyOwner {
        require(!transfersEnabled, "Transfers already enabled");
        transfersEnabled = true;
        emit TransfersEnabled();
    }

    /**
     * @notice Override transfer to enforce non-transferability until maturity
     */
    function _update(address from, address to, uint256 value) internal override {
        // Allow minting (from == address(0)) and burning (to == address(0))
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }
        
        // Block transfers until enabled
        require(transfersEnabled, "Transfers disabled until maturity");
        
        super._update(from, to, value);
    }

    /**
     * @notice Get tranche information
     * @return info Struct containing tranche details
     */
    function getTrancheInfo() external view returns (TrancheInfo memory info) {
        info = TrancheInfo({
            name: name(),
            symbol: symbol(),
            asset: asset,
            totalSupply: totalSupply(),
            transfersEnabled: transfersEnabled,
            launchTime: launchTime,
            bondManager: bondManager
        });
    }

    /**
     * @notice Tranche information struct
     */
    struct TrancheInfo {
        string name;
        string symbol;
        address asset;
        uint256 totalSupply;
        bool transfersEnabled;
        uint256 launchTime;
        address bondManager;
    }

    /**
     * @notice Get holder count (approximate)
     * @dev This is a simplified implementation - in production would use enumerable extension
     */
    function getHolderCount() external view returns (uint256 count) {
        // Simplified: return 1 if total supply > 0
        // In production: implement proper holder enumeration
        count = totalSupply() > 0 ? 1 : 0;
    }

    /**
     * @notice Check if address holds any tokens
     * @param holder Address to check
     * @return hasTokens Whether address holds tokens
     */
    function isHolder(address holder) external view returns (bool hasTokens) {
        hasTokens = balanceOf(holder) > 0;
    }

    /**
     * @notice Get time until maturity (if known)
     * @param maturityTime Expected maturity timestamp
     * @return timeRemaining Seconds until maturity
     */
    function getTimeToMaturity(uint256 maturityTime) external view returns (uint256 timeRemaining) {
        if (block.timestamp >= maturityTime) {
            timeRemaining = 0;
        } else {
            timeRemaining = maturityTime - block.timestamp;
        }
    }

    /**
     * @notice Calculate accrued interest for holder (helper function)
     * @param holder Address to calculate for
     * @param apr Annual percentage rate (scaled by 1e18)
     * @param timeElapsed Time elapsed since subscription
     * @return accruedInterest Accrued interest amount
     */
    function calculateAccruedInterest(
        address holder,
        uint256 apr,
        uint256 timeElapsed
    ) external view returns (uint256 accruedInterest) {
        uint256 principal = balanceOf(holder);
        if (principal == 0) return 0;
        
        // Interest = Principal * APR * (TimeElapsed / 365 days)
        accruedInterest = (principal * apr * timeElapsed) / (1e18 * 365 days);
    }

    /**
     * @notice Emergency pause (disable all operations except owner functions)
     * @dev Only callable by BondManager in emergency situations
     */
    function emergencyPause() external onlyOwner {
        // In production: implement pausable functionality
        // For now, this is a placeholder for emergency controls
    }
}
