// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./GovToken.sol";
import "./Bank.sol";

contract Gov is Ownable {
    GovToken public token;
    Bank public bank;
    
    enum Vote { NONE, FOR, AGAINST }
    
    struct Proposal {
        uint256 id;
        string description;
        uint256 amount;
        address payable recipient;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
    }
    
    Proposal[] public proposals;
    mapping(uint256 => mapping(address => Vote)) public votes;
    
    uint256 public votingDelay = 1 minutes;
    uint256 public votingPeriod = 7 days;
    
    constructor(GovToken _token, Bank _bank) Ownable(msg.sender) {
        token = _token;
        bank = _bank;
        transferOwnership(address(this)); // 将Bank的管理权交给本合约
    }
    
    // 创建新提案
    function propose(
        string memory description,
        uint256 amount,
        address payable recipient
    ) external {
        require(token.balanceOf(msg.sender) > 0, "Must hold tokens to propose");
        
        proposals.push(Proposal({
            id: proposals.length,
            description: description,
            amount: amount,
            recipient: recipient,
            startTime: block.timestamp + votingDelay,
            endTime: block.timestamp + votingDelay + votingPeriod,
            forVotes: 0,
            againstVotes: 0,
            executed: false
        }));
    }
    
    // 投票
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(votes[proposalId][msg.sender] == Vote.NONE, "Already voted");
        
        uint256 voterBalance = token.balanceOf(msg.sender);
        require(voterBalance > 0, "No voting power");
        
        if (support) {
            proposal.forVotes += voterBalance;
        } else {
            proposal.againstVotes += voterBalance;
        }
        
        votes[proposalId][msg.sender] = support ? Vote.FOR : Vote.AGAINST;
    }
    
    // 执行提案
    function execute(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");
        
        proposal.executed = true;
        bank.withdraw(proposal.amount, proposal.recipient);
    }
    
    // 获取提案数量
    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }
}