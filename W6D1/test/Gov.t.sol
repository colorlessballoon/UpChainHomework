// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/GovToken.sol";
import "../src/Bank.sol";
import "../src/Gov.sol";

contract GovBankTest is Test {
    GovToken public token;
    Bank public bank;
    Gov public gov;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public recipient = address(0x4);
    
    uint256 public initialSupply = 1000000 * 10**18;
    uint256 public depositAmount = 10 ether;
    
    function setUp() public {
        // 部署合约
        token = new GovToken();
        bank = new Bank();
        gov = new Gov(token, bank);
        
        // 转移 Bank 合约的所有权给 Gov 合约
        bank.transferOwnership(address(gov));
        
        // 分配代币
        token.mint(alice, 1000 * 10**18);
        token.mint(bob, 500 * 10**18);
        token.mint(charlie, 200 * 10**18);
        
        // 存入ETH到Bank
        vm.deal(address(this), depositAmount);
        (bool success,) = address(bank).call{value: depositAmount}("");
        require(success, "Deposit failed");
    }
    
    // 测试创建提案
    function testCreateProposal() public {
        vm.startPrank(alice);
        
        string memory description = "Send 1 ETH to team";
        uint256 amount = 1 ether;
        
        // 创建提案
        gov.propose(description, amount, payable(recipient));
        
        // 检查提案
        (uint256 id, , uint256 propAmount, address propRecipient, , , , , ) = gov.proposals(0);
        assertEq(id, 0);
        assertEq(propAmount, amount);
        assertEq(propRecipient, recipient);
        
        vm.stopPrank();
    }
    
    // 测试投票和执行提案
    function testVoteAndExecuteProposal() public {
        // 创建提案
        vm.startPrank(alice);
        uint256 proposalTime = block.timestamp;
        gov.propose("Send 1 ETH to team", 1 ether, payable(recipient));
        vm.stopPrank();
        
        // 快进到投票开始
        vm.warp(proposalTime + gov.votingDelay() + 1);
        
        // Alice 投票赞成
        vm.prank(alice);
        gov.vote(0, true);
        
        // Bob 投票反对
        vm.prank(bob);
        gov.vote(0, false);
        
        // Charlie 投票赞成
        vm.prank(charlie);
        gov.vote(0, true);
        
        // 检查投票结果
        (, , , , , , uint256 forVotes, uint256 againstVotes, ) = gov.proposals(0);
        assertEq(forVotes, 1200 * 10**18); // Alice 1000 + Charlie 200
        assertEq(againstVotes, 500 * 10**18); // Bob 500
        
        // 快进到投票结束
        vm.warp(proposalTime + gov.votingDelay() + gov.votingPeriod() + 1);
        
        // 执行提案
        gov.execute(0);
        
        // 检查Bank余额
        assertEq(address(bank).balance, depositAmount - 1 ether);
        assertEq(recipient.balance, 1 ether);
        
        // 检查提案状态
        (, , , , , , , , bool executed) = gov.proposals(0);
        assertTrue(executed);
    }
    
    // 测试提案被拒绝的情况
    function testRejectedProposal() public {
        // 创建提案
        vm.startPrank(alice);
        uint256 proposalTime = block.timestamp;
        gov.propose("Send 1 ETH to team", 1 ether, payable(recipient));
        vm.stopPrank();
        
        // 快进到投票开始
        vm.warp(proposalTime + gov.votingDelay() + 1);
        
        // Alice 投票反对
        vm.prank(alice);
        gov.vote(0, false);
        
        // Bob 投票反对
        vm.prank(bob);
        gov.vote(0, false);
        
        // Charlie 投票反对
        vm.prank(charlie);
        gov.vote(0, false);
        
        // 检查投票结果
        (, , , , , , uint256 forVotes, uint256 againstVotes, ) = gov.proposals(0);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 1700 * 10**18);
        
        // 快进到投票结束
        vm.warp(proposalTime + gov.votingDelay() + gov.votingPeriod() + 1);
        
        // 尝试执行提案（应该失败）
        vm.expectRevert("Proposal rejected");
        gov.execute(0);
        
        // 检查Bank余额未变化
        assertEq(address(bank).balance, depositAmount);
    }
    
    // 测试未持有代币的用户不能创建提案
    function testCannotProposeWithoutTokens() public {
        address noTokensUser = address(0x5);
        
        vm.expectRevert("Must hold tokens to propose");
        vm.prank(noTokensUser);
        gov.propose("Invalid proposal", 1 ether, payable(recipient));
    }
    
    // 测试投票期间不能执行提案
    function testCannotExecuteDuringVoting() public {
        // 创建提案
        vm.startPrank(alice);
        gov.propose("Send 1 ETH to team", 1 ether, payable(recipient));
        vm.stopPrank();
        
        // 快进到投票开始
        vm.warp(gov.votingDelay() + 1);
        
        // 尝试执行（应该失败）
        vm.expectRevert("Voting not ended");
        gov.execute(0);
    }
    
    // 测试不能重复投票
    function testCannotVoteTwice() public {
        // 创建提案
        vm.startPrank(alice);
        gov.propose("Send 1 ETH to team", 1 ether, payable(recipient));
        vm.stopPrank();
        
        // 快进到投票开始
        vm.warp(gov.votingDelay() + 1);
        
        // Alice 第一次投票
        vm.prank(alice);
        gov.vote(0, true);
        
        // Alice 尝试第二次投票
        vm.expectRevert("Already voted");
        vm.prank(alice);
        gov.vote(0, true);
    }
    
    // 测试提案执行后不能再次执行
    function testCannotExecuteTwice() public {
        // 创建提案
        vm.startPrank(alice);
        uint256 proposalTime = block.timestamp;
        gov.propose("Send 1 ETH to team", 1 ether, payable(recipient));
        vm.stopPrank();
        
        // 快进到投票开始
        vm.warp(proposalTime + gov.votingDelay() + 1);
        
        // 全部赞成
        vm.prank(alice);
        gov.vote(0, true);
        vm.prank(bob);
        gov.vote(0, true);
        
        // 快进到投票结束
        vm.warp(proposalTime + gov.votingDelay() + gov.votingPeriod() + 1);
        
        // 第一次执行
        gov.execute(0);
        
        // 尝试第二次执行
        vm.expectRevert("Already executed");
        gov.execute(0);
    }
    
    // 接收ETH用于测试
    receive() external payable {}
}