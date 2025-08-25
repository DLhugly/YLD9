// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITreasuryManager.sol";

/**
 * @title TreasuryManager
 * @notice Multi-protocol rebalancing controller with dynamic allocation
 * @dev Manages integrations with Aave, WLF, Uniswap V3, Aerodrome
 */
contract TreasuryManager is ITreasuryManager, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Protocol adapter addresses
    mapping(string => address) public protocolAdapters;
    
    /// @notice Protocol allocation limits (basis points)
    mapping(string => uint256) public protocolLimits;
    
    /// @notice Current protocol allocations
    mapping(string => uint256) public protocolAllocations;
    
    /// @notice Supported assets
    mapping(address => bool) public supportedAssets;
    
    /// @notice Asset balances by protocol
    mapping(string => mapping(address => uint256)) public protocolBalances;
    
    /// @notice Protocol names array
    string[] public protocolNames;
    
    /// @notice Total assets under management
    uint256 public totalAUM;
    
    /// @notice Maximum basis points
    uint256 public constant MAX_BPS = 10000;
    
    /// @notice Events
    event ProtocolAdded(string name, address adapter, uint256 limit);
    event ProtocolUpdated(string name, address adapter, uint256 limit);
    event Rebalanced(string protocol, uint256 oldAllocation, uint256 newAllocation);
    event YieldHarvested(string protocol, uint256 amount);
    event EmergencyWithdrawal(string protocol, uint256 amount);

    constructor() Ownable(msg.sender) {
        // Initialize with Base L2 protocol limits from roadmap
        _addProtocol("Aave", address(0), 6000);     // 60% max
        _addProtocol("WLF", address(0), 4000);      // 40% max  
        _addProtocol("UniswapV3", address(0), 3000); // 30% max
        _addProtocol("Aerodrome", address(0), 3000); // 30% max
    }

    /**
     * @notice Add or update protocol adapter
     * @param name Protocol name
     * @param adapter Adapter contract address
     * @param limitBps Allocation limit in basis points
     */
    function addProtocol(string calldata name, address adapter, uint256 limitBps) external onlyOwner {
        require(adapter != address(0), "Invalid adapter");
        require(limitBps <= MAX_BPS, "Invalid limit");
        
        if (protocolAdapters[name] == address(0)) {
            protocolNames.push(name);
            emit ProtocolAdded(name, adapter, limitBps);
        } else {
            emit ProtocolUpdated(name, adapter, limitBps);
        }
        
        protocolAdapters[name] = adapter;
        protocolLimits[name] = limitBps;
    }

    /**
     * @notice Add supported asset
     * @param asset Asset address to support
     */
    function addSupportedAsset(address asset) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        supportedAssets[asset] = true;
    }

    /**
     * @notice Harvest yield from all integrated protocols
     * @return totalYield Total yield harvested across all protocols
     */
    function harvestAll() external override onlyOwner returns (uint256 totalYield) {
        for (uint256 i = 0; i < protocolNames.length; i++) {
            string memory protocol = protocolNames[i];
            address adapter = protocolAdapters[protocol];
            
            if (adapter != address(0)) {
                // In production: call adapter.harvest()
                uint256 yield = _simulateHarvest(protocol);
                totalYield += yield;
                
                emit YieldHarvested(protocol, yield);
            }
        }
    }

    /**
     * @notice Rebalance assets across protocols
     * @param requiredIdle Minimum idle buffer to maintain
     */
    function rebalance(uint256 requiredIdle) external override onlyOwner {
        uint256 totalAssets = totalAUM;
        uint256 availableForRebalance = totalAssets > requiredIdle ? 
            totalAssets - requiredIdle : 0;
        
        // Calculate optimal allocation based on risk-adjusted yields
        uint256[] memory targetAllocations = _calculateOptimalAllocation(availableForRebalance);
        
        // Execute rebalancing
        for (uint256 i = 0; i < protocolNames.length; i++) {
            string memory protocol = protocolNames[i];
            uint256 currentAllocation = protocolAllocations[protocol];
            uint256 targetAllocation = targetAllocations[i];
            
            if (targetAllocation != currentAllocation) {
                _rebalanceProtocol(protocol, currentAllocation, targetAllocation);
                
                emit Rebalanced(protocol, currentAllocation, targetAllocation);
            }
        }
    }

    /**
     * @notice Rebalance to prepare for a specific asset withdrawal
     * @param asset Asset to prepare for withdrawal
     * @param amount Amount needed for withdrawal
     */
    function rebalanceForWithdrawal(address asset, uint256 amount) external override onlyOwner {
        require(supportedAssets[asset], "Unsupported asset");
        
        // Find protocols with the required asset and withdraw
        uint256 remaining = amount;
        
        for (uint256 i = 0; i < protocolNames.length && remaining > 0; i++) {
            string memory protocol = protocolNames[i];
            uint256 available = protocolBalances[protocol][asset];
            
            if (available > 0) {
                uint256 toWithdraw = available >= remaining ? remaining : available;
                
                // In production: call adapter.withdraw(asset, toWithdraw)
                protocolBalances[protocol][asset] -= toWithdraw;
                protocolAllocations[protocol] -= toWithdraw;
                remaining -= toWithdraw;
            }
        }
        
        require(remaining == 0, "Insufficient liquidity");
    }

    /**
     * @notice Get total assets deployed across all protocols
     * @return Total deployed assets in USD terms
     */
    function getTotalDeployed() external view override returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < protocolNames.length; i++) {
            total += protocolAllocations[protocolNames[i]];
        }
        return total;
    }

    /**
     * @notice Emergency withdraw all funds from protocols
     */
    function emergencyWithdraw() external override onlyOwner {
        for (uint256 i = 0; i < protocolNames.length; i++) {
            string memory protocol = protocolNames[i];
            uint256 allocation = protocolAllocations[protocol];
            
            if (allocation > 0) {
                // In production: call adapter.emergencyWithdraw()
                protocolAllocations[protocol] = 0;
                
                emit EmergencyWithdrawal(protocol, allocation);
            }
        }
    }

    /**
     * @notice Get allocation breakdown across protocols
     * @return protocols Array of protocol names
     * @return allocations Array of allocation amounts
     */
    function getAllocationBreakdown() external view override returns (address[] memory protocols, uint256[] memory allocations) {
        protocols = new address[](protocolNames.length);
        allocations = new uint256[](protocolNames.length);
        
        for (uint256 i = 0; i < protocolNames.length; i++) {
            protocols[i] = protocolAdapters[protocolNames[i]];
            allocations[i] = protocolAllocations[protocolNames[i]];
        }
    }

    /**
     * @notice Get protocol allocation limits
     * @return names Array of protocol names
     * @return limits Array of allocation limits in basis points
     */
    function getProtocolLimits() external view returns (string[] memory names, uint256[] memory limits) {
        names = new string[](protocolNames.length);
        limits = new uint256[](protocolNames.length);
        
        for (uint256 i = 0; i < protocolNames.length; i++) {
            names[i] = protocolNames[i];
            limits[i] = protocolLimits[protocolNames[i]];
        }
    }

    /**
     * @notice Get current protocol allocations
     * @return names Array of protocol names
     * @return allocations Array of current allocations
     */
    function getCurrentAllocations() external view returns (string[] memory names, uint256[] memory allocations) {
        names = new string[](protocolNames.length);
        allocations = new uint256[](protocolNames.length);
        
        for (uint256 i = 0; i < protocolNames.length; i++) {
            names[i] = protocolNames[i];
            allocations[i] = protocolAllocations[protocolNames[i]];
        }
    }

    /**
     * @notice Internal functions
     */
    function _addProtocol(string memory name, address adapter, uint256 limitBps) internal {
        protocolNames.push(name);
        protocolAdapters[name] = adapter;
        protocolLimits[name] = limitBps;
    }

    function _calculateOptimalAllocation(uint256 totalAmount) internal view returns (uint256[] memory allocations) {
        allocations = new uint256[](protocolNames.length);
        
        // Simplified allocation strategy - in production use risk-adjusted yields
        // For now, prioritize Aave (safest) then distribute based on limits
        
        uint256 remaining = totalAmount;
        
        // Aave gets priority (up to limit)
        uint256 aaveMax = (totalAmount * protocolLimits["Aave"]) / MAX_BPS;
        allocations[0] = remaining >= aaveMax ? aaveMax : remaining;
        remaining -= allocations[0];
        
        // Distribute remaining across other protocols
        for (uint256 i = 1; i < protocolNames.length && remaining > 0; i++) {
            string memory protocol = protocolNames[i];
            uint256 maxAllocation = (totalAmount * protocolLimits[protocol]) / MAX_BPS;
            
            allocations[i] = remaining >= maxAllocation ? maxAllocation : remaining;
            remaining -= allocations[i];
        }
    }

    function _rebalanceProtocol(string memory protocol, uint256 currentAllocation, uint256 targetAllocation) internal {
        if (targetAllocation > currentAllocation) {
            // Increase allocation - deposit more
            uint256 toDeposit = targetAllocation - currentAllocation;
            // In production: call adapter.deposit(assets, amounts)
            protocolAllocations[protocol] = targetAllocation;
        } else {
            // Decrease allocation - withdraw excess
            uint256 toWithdraw = currentAllocation - targetAllocation;
            // In production: call adapter.withdraw(assets, amounts)
            protocolAllocations[protocol] = targetAllocation;
        }
    }

    function _simulateHarvest(string memory protocol) internal view returns (uint256 yield) {
        // Simplified yield simulation - in production call adapter.harvest()
        uint256 allocation = protocolAllocations[protocol];
        
        if (keccak256(bytes(protocol)) == keccak256(bytes("Aave"))) {
            yield = (allocation * 3) / 100 / 52; // 3% APR weekly
        } else if (keccak256(bytes(protocol)) == keccak256(bytes("WLF"))) {
            yield = (allocation * 5) / 100 / 52; // 5% APR weekly
        } else {
            yield = (allocation * 7) / 100 / 52; // 7% APR weekly for LP strategies
        }
    }

    /**
     * @notice Update total AUM (called by vault)
     * @param newAUM New total assets under management
     */
    function updateTotalAUM(uint256 newAUM) external onlyOwner {
        totalAUM = newAUM;
    }
}
