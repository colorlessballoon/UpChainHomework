// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/CallOptionToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 模拟 ERC20 代币用于测试
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CallOptionTokenTest is Test {
    CallOptionToken public optionToken;
    MockERC20 public underlyingAsset; // 标的资产
    MockERC20 public quoteAsset;      // 计价资产
    
    address public owner = address(1);
    address public user = address(2);
    uint256 public constant STRIKE_PRICE = 1000; // 1:1000 的行权价格
    uint256 public constant EXPIRATION = 1735689600; // 2025-01-01
    
    function setUp() public {
        // 部署模拟代币
        underlyingAsset = new MockERC20("Underlying Asset", "UA");
        quoteAsset = new MockERC20("Quote Asset", "QA");
        
        // 切换到 owner 地址
        vm.startPrank(owner);
        
        // 部署期权合约
        optionToken = new CallOptionToken(
            "Test Call Option",
            "TCO",
            address(underlyingAsset),
            address(quoteAsset),
            STRIKE_PRICE,
            EXPIRATION
        );
        
        vm.stopPrank();
        
        // 给 owner 和 user 铸造代币
        underlyingAsset.mint(owner, 1000 * 10**18);
        quoteAsset.mint(owner, 1000000 * 10**18);
        underlyingAsset.mint(user, 1000 * 10**18);
        quoteAsset.mint(user, 1000000 * 10**18);
    }
    
    function test_IssueOption() public {
        uint256 issueAmount = 100 * 10**18;
        
        // owner 发行期权
        vm.startPrank(owner);
        underlyingAsset.approve(address(optionToken), issueAmount);
        optionToken.issue(user, issueAmount);
        vm.stopPrank();
        
        // 验证用户收到的期权数量
        assertEq(optionToken.balanceOf(user), issueAmount);
        // 验证合约持有的标的资产数量
        assertEq(underlyingAsset.balanceOf(address(optionToken)), issueAmount);
    }
    
    function test_ExerciseOption() public {
        uint256 issueAmount = 100 * 10**18;
        uint256 exerciseAmount = 50 * 10**18;
        
        // 先发行期权
        vm.startPrank(owner);
        underlyingAsset.approve(address(optionToken), issueAmount);
        optionToken.issue(user, issueAmount);
        vm.stopPrank();
        
        // 用户行权
        vm.startPrank(user);
        uint256 quoteAmount = exerciseAmount * STRIKE_PRICE / 10**18;
        quoteAsset.approve(address(optionToken), quoteAmount);
        optionToken.exercise(exerciseAmount);
        vm.stopPrank();
        
        // 验证用户持有的期权数量减少
        assertEq(optionToken.balanceOf(user), issueAmount - exerciseAmount);
        // 验证用户收到的标的资产数量（原有+新获得）
        assertEq(underlyingAsset.balanceOf(user), 1000 * 10**18 + exerciseAmount);
        // 验证合约收到的报价资产数量
        assertEq(quoteAsset.balanceOf(address(optionToken)), quoteAmount);
    }
    
    function test_RevertWhen_ExerciseAfterExpiration() public {
        uint256 issueAmount = 100 * 10**18;
        
        // 先发行期权
        vm.startPrank(owner);
        underlyingAsset.approve(address(optionToken), issueAmount);
        optionToken.issue(user, issueAmount);
        vm.stopPrank();
        
        // 时间快进到过期后
        vm.warp(EXPIRATION + 1 days);
        
        // 尝试行权（应该失败）
        vm.startPrank(user);
        uint256 quoteAmount = issueAmount * STRIKE_PRICE / 10**18;
        quoteAsset.approve(address(optionToken), quoteAmount);
        
        // 期望交易回滚，并显示 "Option expired" 错误信息
        vm.expectRevert("Option expired");
        optionToken.exercise(issueAmount);
    }
    
    function test_SettleAfterExpiration() public {
        uint256 issueAmount = 100 * 10**18;
        
        // 先发行期权
        vm.startPrank(owner);
        underlyingAsset.approve(address(optionToken), issueAmount);
        optionToken.issue(user, issueAmount);
        vm.stopPrank();
        
        // user 把 optionToken 转给合约（模拟未行权的 token 被合约持有）
        vm.startPrank(user);
        optionToken.transfer(address(optionToken), issueAmount);
        vm.stopPrank();
        
        // 时间快进到过期后
        vm.warp(EXPIRATION + 1 days);
        
        // 执行清算
        vm.startPrank(owner);
        optionToken.settle();
        vm.stopPrank();
        
        // 验证清算状态
        assertTrue(optionToken.isSettled());
        // 验证标的资产已返还给 owner
        assertEq(underlyingAsset.balanceOf(owner), 1000 * 10**18);
    }
} 