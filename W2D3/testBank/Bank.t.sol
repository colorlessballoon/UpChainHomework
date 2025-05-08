// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/Bank.sol";

contract BankTest is Test {
    Bank bank;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    address user4 = address(0x4);

    function setUp() public {
        // 移除 vm.prank(user1)，让测试合约成为所有者
        bank = new Bank();
    }

    function testDepositUpdatesBalance() public {
        // 检查初始余额为0
        assertEq(bank.balances(user1), 0);
        
        // User1 存入 1 ether
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        console.log("User1 balance after deposit:", bank.balances(user1));
        assertEq(bank.balances(user1), 1 ether);
        assertEq(address(bank).balance, 1 ether); 

        // User1 再存入 2 ether
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        bank.deposit{value: 2 ether}();
        console.log("User1 balance after second deposit:", bank.balances(user1));
        assertEq(bank.balances(user1), 3 ether);
        assertEq(address(bank).balance, 3 ether);
    }

    function testTop3UsersEmpty() public view{
    // 检查初始状态 top3 都是空地址
        assertEq(bank.top3(0), address(0));
        assertEq(bank.top3(1), address(0));
        assertEq(bank.top3(2), address(0));
    }

    function testTop3Users() public {
        // User1 deposits 1 ether
        vm.prank(user1);
        vm.deal(user1, 1 ether);
        bank.deposit{value: 1 ether}();
        assertEq(bank.top3(0), user1);

        // User2 deposits 2 ether
        vm.prank(user2);
        vm.deal(user2, 2 ether);
        bank.deposit{value: 2 ether}();
        assertEq(bank.top3(0), user2);
        assertEq(bank.top3(1), user1);

        // User3 deposits 3 ether
        vm.prank(user3);
        vm.deal(user3, 3 ether);
        bank.deposit{value: 3 ether}();
        assertEq(bank.top3(0), user3);
        assertEq(bank.top3(1), user2);
        assertEq(bank.top3(2), user1);

        // User4 deposits 4 ether
        vm.prank(user4);
        vm.deal(user4, 4 ether);
        bank.deposit{value: 4 ether}();
        assertEq(bank.top3(0), user4);
        assertEq(bank.top3(1), user3);
        assertEq(bank.top3(2), user2);

        // User1 deposits another 5 ether
        vm.prank(user1);
        vm.deal(user1, 5 ether);
        bank.deposit{value: 5 ether}();
        assertEq(bank.top3(0), user1);
        assertEq(bank.top3(1), user4);
        assertEq(bank.top3(2), user3);
    }
    
    function testOnlyOwnerCanWithdraw() public {
        // 先存入一些 ETH
        vm.deal(user1, 5 ether);
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        // 验证合约余额
        assertEq(address(bank).balance, 5 ether);
        
        // 验证当前所有者
        assertEq(bank.owner(), address(this));

        // 所有者提取 3 ether
        bank.withDraw(3 ether);
        assertEq(address(bank).balance, 2 ether);

        // 非所有者尝试提取
        vm.prank(user2);
        vm.expectRevert("Only the owner can withdraw");
        bank.withDraw(1 ether);
    }

    function testReceiveFunction() public {
        // 测试 receive 函数
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        (bool success,) = address(bank).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(bank.balances(user1), 1 ether);
    }

    receive() external payable {
        
    }

}