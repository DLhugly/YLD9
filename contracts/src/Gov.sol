// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Gov
 * @notice Dual governance system for Agonic protocol (AGN holders + LP stakers)
 * @dev LP stakers can vote on protocol integrations and high-risk strategies
 */
contract Gov is Ownable, ReentrancyGuard {
    /// @notice AGN token for governance
    IERC20 public immutable AGN;
    
    /// @notice Proposal counter
    uint256 public proposalCount;
    
    /// @notice Voting delay (time between proposal creation and voting start)
    uint256 public votingDelay = 1 days;
    
    /// @notice Voting period duration
    uint256 public votingPeriod = 7 days;
    
    /// @notice Minimum AGN required to create proposal
    uint256 public proposalThreshold = 10000e18; // 10k AGN
    
    /// @notice Quorum percentage (basis points)
    uint256 public quorumBps = 400; // 4%
    
    /// @notice LP staker registry
    mapping(address => LPStaker) public lpStakers;
    mapping(address => bool) public isLPStaker;
    
    /// @notice Proposals mapping
    mapping(uint256 => Proposal) public proposals;
    
    /// @notice Votes mapping: proposalId => voter => hasVoted
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    /// @notice Vote choices: proposalId => voter => choice
    mapping(uint256 => mapping(address => VoteChoice)) public voteChoices;
    
    /// @notice Proposal states
    enum ProposalState {
        Pending,    // Created but voting not started
        Active,     // Voting in progress
        Succeeded,  // Passed
        Failed,     // Failed to meet quorum or majority
        Executed,   // Successfully executed
        Cancelled   // Cancelled by proposer or admin
    }
    
    /// @notice Vote choices
    enum VoteChoice {
        Against,
        For,
        Abstain
    }
    
    /// @notice LP staker information
    struct LPStaker {
        uint256 lpTokens;      // Amount of LP tokens staked
        uint256 lockDuration;  // Lock duration in seconds
        uint256 lockEnd;       // When lock expires
        uint256 votingWeight;  // Calculated voting weight
        bool active;           // Whether staker is active
    }
    
    /// @notice Proposal structure
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        bytes32 category; // "parameter", "integration", "emergency", etc.
        uint256 createdAt;
        uint256 votingStartTime;
        uint256 votingEndTime;
        uint256 agnForVotes;
        uint256 agnAgainstVotes;
        uint256 agnAbstainVotes;
        uint256 lpForVotes;
        uint256 lpAgainstVotes;
        uint256 lpAbstainVotes;
        ProposalState state;
        bool requiresLPApproval; // Whether LP stakers must approve
        bytes executionData;     // Encoded function call for execution
        address target;          // Contract to call for execution
    }
    
    /// @notice Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        bool requiresLPApproval
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        VoteChoice choice,
        uint256 weight,
        bool isLPVote
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event LPStakerRegistered(address indexed staker, uint256 lpTokens, uint256 lockDuration);
    event LPStakerUpdated(address indexed staker, uint256 newWeight);

    constructor(address _agn) Ownable(msg.sender) {
        AGN = IERC20(_agn);
    }

    /**
     * @notice Create a new proposal
     * @param title Proposal title
     * @param description Proposal description
     * @param category Proposal category
     * @param requiresLPApproval Whether LP stakers must approve
     * @param target Contract address for execution
     * @param executionData Encoded function call
     * @return proposalId New proposal ID
     */
    function createProposal(
        string calldata title,
        string calldata description,
        string calldata category,
        bool requiresLPApproval,
        address target,
        bytes calldata executionData
    ) external returns (uint256 proposalId) {
        require(AGN.balanceOf(msg.sender) >= proposalThreshold, "Insufficient AGN balance");
        require(bytes(title).length > 0, "Empty title");
        require(bytes(description).length > 0, "Empty description");
        
        proposalId = ++proposalCount;
        
        uint256 votingStartTime = block.timestamp + votingDelay;
        uint256 votingEndTime = votingStartTime + votingPeriod;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            category: keccak256(bytes(category)),
            createdAt: block.timestamp,
            votingStartTime: votingStartTime,
            votingEndTime: votingEndTime,
            agnForVotes: 0,
            agnAgainstVotes: 0,
            agnAbstainVotes: 0,
            lpForVotes: 0,
            lpAgainstVotes: 0,
            lpAbstainVotes: 0,
            state: ProposalState.Pending,
            requiresLPApproval: requiresLPApproval,
            executionData: executionData,
            target: target
        });
        
        emit ProposalCreated(proposalId, msg.sender, title, requiresLPApproval);
    }

    /**
     * @notice Cast vote on proposal
     * @param proposalId Proposal ID to vote on
     * @param choice Vote choice (Against, For, Abstain)
     */
    function castVote(uint256 proposalId, VoteChoice choice) external nonReentrant {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Active, "Voting not active");
        require(block.timestamp >= proposal.votingStartTime, "Voting not started");
        require(block.timestamp <= proposal.votingEndTime, "Voting ended");
        
        hasVoted[proposalId][msg.sender] = true;
        voteChoices[proposalId][msg.sender] = choice;
        
        // AGN holder voting
        uint256 agnBalance = AGN.balanceOf(msg.sender);
        if (agnBalance > 0) {
            if (choice == VoteChoice.For) {
                proposal.agnForVotes += agnBalance;
            } else if (choice == VoteChoice.Against) {
                proposal.agnAgainstVotes += agnBalance;
            } else {
                proposal.agnAbstainVotes += agnBalance;
            }
            
            emit VoteCast(proposalId, msg.sender, choice, agnBalance, false);
        }
        
        // LP staker voting (if applicable)
        if (isLPStaker[msg.sender] && lpStakers[msg.sender].active) {
            uint256 lpWeight = lpStakers[msg.sender].votingWeight;
            
            if (choice == VoteChoice.For) {
                proposal.lpForVotes += lpWeight;
            } else if (choice == VoteChoice.Against) {
                proposal.lpAgainstVotes += lpWeight;
            } else {
                proposal.lpAbstainVotes += lpWeight;
            }
            
            emit VoteCast(proposalId, msg.sender, choice, lpWeight, true);
        }
    }

    /**
     * @notice Update proposal state after voting period
     * @param proposalId Proposal ID to update
     */
    function updateProposalState(uint256 proposalId) external {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Pending || proposal.state == ProposalState.Active, "Invalid state");
        
        if (block.timestamp < proposal.votingStartTime) {
            proposal.state = ProposalState.Pending;
        } else if (block.timestamp <= proposal.votingEndTime) {
            proposal.state = ProposalState.Active;
        } else {
            // Voting ended, determine result
            bool passed = _checkProposalPassed(proposalId);
            proposal.state = passed ? ProposalState.Succeeded : ProposalState.Failed;
        }
    }

    /**
     * @notice Execute a successful proposal
     * @param proposalId Proposal ID to execute
     */
    function executeProposal(uint256 proposalId) external {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Succeeded, "Proposal not successful");
        
        proposal.state = ProposalState.Executed;
        
        // Execute the proposal
        if (proposal.target != address(0) && proposal.executionData.length > 0) {
            (bool success, ) = proposal.target.call(proposal.executionData);
            require(success, "Execution failed");
        }
        
        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Check if proposal passed
     * @param proposalId Proposal ID to check
     * @return passed Whether proposal passed
     */
    function _checkProposalPassed(uint256 proposalId) internal view returns (bool passed) {
        Proposal storage proposal = proposals[proposalId];
        
        // Check AGN holder votes
        uint256 totalAGNVotes = proposal.agnForVotes + proposal.agnAgainstVotes + proposal.agnAbstainVotes;
        uint256 agnSupply = AGN.totalSupply();
        bool agnQuorumMet = (totalAGNVotes * 10000) / agnSupply >= quorumBps;
        bool agnMajority = proposal.agnForVotes > proposal.agnAgainstVotes;
        
        // If LP approval required, check LP votes
        bool lpApproved = true;
        if (proposal.requiresLPApproval) {
            uint256 totalLPVotes = proposal.lpForVotes + proposal.lpAgainstVotes + proposal.lpAbstainVotes;
            if (totalLPVotes > 0) {
                lpApproved = proposal.lpForVotes > proposal.lpAgainstVotes;
            }
        }
        
        passed = agnQuorumMet && agnMajority && lpApproved;
    }

    /**
     * @notice Register as LP staker
     * @param lpTokens Amount of LP tokens staked
     * @param lockDuration Lock duration in seconds
     */
    function registerLPStaker(uint256 lpTokens, uint256 lockDuration) external {
        require(lpTokens > 0, "Invalid LP tokens");
        require(lockDuration >= 7 days, "Minimum 1 week lock");
        require(lockDuration <= 4 * 365 days, "Maximum 4 years lock");
        
        // Calculate voting weight based on tokens and lock duration
        uint256 votingWeight = _calculateLPVotingWeight(lpTokens, lockDuration);
        
        lpStakers[msg.sender] = LPStaker({
            lpTokens: lpTokens,
            lockDuration: lockDuration,
            lockEnd: block.timestamp + lockDuration,
            votingWeight: votingWeight,
            active: true
        });
        
        isLPStaker[msg.sender] = true;
        
        emit LPStakerRegistered(msg.sender, lpTokens, lockDuration);
    }

    /**
     * @notice Update LP staker information
     * @param staker LP staker address
     * @param newLPTokens New LP token amount
     * @param newLockDuration New lock duration
     */
    function updateLPStaker(address staker, uint256 newLPTokens, uint256 newLockDuration) external onlyOwner {
        require(isLPStaker[staker], "Not an LP staker");
        require(newLPTokens > 0, "Invalid LP tokens");
        
        uint256 newWeight = _calculateLPVotingWeight(newLPTokens, newLockDuration);
        
        lpStakers[staker].lpTokens = newLPTokens;
        lpStakers[staker].lockDuration = newLockDuration;
        lpStakers[staker].lockEnd = block.timestamp + newLockDuration;
        lpStakers[staker].votingWeight = newWeight;
        
        emit LPStakerUpdated(staker, newWeight);
    }

    /**
     * @notice Calculate LP voting weight based on tokens and lock duration
     * @param lpTokens Amount of LP tokens
     * @param lockDuration Lock duration in seconds
     * @return weight Calculated voting weight
     */
    function _calculateLPVotingWeight(uint256 lpTokens, uint256 lockDuration) internal pure returns (uint256 weight) {
        // Base weight = LP tokens
        // Time multiplier: 1x for 1 week, 2.5x for 4 years (linear)
        uint256 minLock = 7 days;
        uint256 maxLock = 4 * 365 days;
        uint256 timeMultiplier = 1e18 + ((lockDuration - minLock) * 15e17) / (maxLock - minLock); // 1x to 2.5x
        
        weight = (lpTokens * timeMultiplier) / 1e18;
    }

    /**
     * @notice Cancel proposal (proposer or admin)
     * @param proposalId Proposal ID to cancel
     */
    function cancelProposal(uint256 proposalId) external {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Not authorized to cancel"
        );
        require(
            proposal.state == ProposalState.Pending || proposal.state == ProposalState.Active,
            "Cannot cancel"
        );
        
        proposal.state = ProposalState.Cancelled;
        emit ProposalCancelled(proposalId);
    }

    /**
     * @notice Get proposal details
     * @param proposalId Proposal ID
     * @return proposal Proposal struct
     */
    function getProposal(uint256 proposalId) external view returns (Proposal memory proposal) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        proposal = proposals[proposalId];
    }

    /**
     * @notice Get proposal state
     * @param proposalId Proposal ID
     * @return state Current proposal state
     */
    function getProposalState(uint256 proposalId) external view returns (ProposalState state) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.state == ProposalState.Executed || 
            proposal.state == ProposalState.Cancelled ||
            proposal.state == ProposalState.Failed) {
            return proposal.state;
        }
        
        if (block.timestamp < proposal.votingStartTime) {
            return ProposalState.Pending;
        } else if (block.timestamp <= proposal.votingEndTime) {
            return ProposalState.Active;
        } else {
            bool passed = _checkProposalPassed(proposalId);
            return passed ? ProposalState.Succeeded : ProposalState.Failed;
        }
    }

    /**
     * @notice Update governance parameters
     * @param parameter Parameter name
     * @param value New value
     */
    function updateParameter(string calldata parameter, uint256 value) external onlyOwner {
        bytes32 paramHash = keccak256(bytes(parameter));
        
        if (paramHash == keccak256(bytes("votingDelay"))) {
            require(value >= 1 hours && value <= 7 days, "Invalid voting delay");
            votingDelay = value;
        } else if (paramHash == keccak256(bytes("votingPeriod"))) {
            require(value >= 1 days && value <= 30 days, "Invalid voting period");
            votingPeriod = value;
        } else if (paramHash == keccak256(bytes("proposalThreshold"))) {
            require(value > 0, "Invalid threshold");
            proposalThreshold = value;
        } else if (paramHash == keccak256(bytes("quorumBps"))) {
            require(value >= 100 && value <= 2000, "Invalid quorum"); // 1-20%
            quorumBps = value;
        } else {
            revert("Unknown parameter");
        }
    }

    /**
     * @notice Get LP staker information
     * @param staker LP staker address
     * @return stakerInfo LP staker struct
     */
    function getLPStaker(address staker) external view returns (LPStaker memory stakerInfo) {
        require(isLPStaker[staker], "Not an LP staker");
        stakerInfo = lpStakers[staker];
    }

    /**
     * @notice Get voting power for address
     * @param voter Voter address
     * @return agnPower AGN voting power
     * @return lpPower LP voting power
     */
    function getVotingPower(address voter) external view returns (uint256 agnPower, uint256 lpPower) {
        agnPower = AGN.balanceOf(voter);
        
        if (isLPStaker[voter] && lpStakers[voter].active) {
            lpPower = lpStakers[voter].votingWeight;
        }
    }
}
