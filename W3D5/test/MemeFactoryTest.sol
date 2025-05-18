// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    // 合约和地址变量
    MemeFactory public factory;
    MemeToken public implementation;
    address public projectOwner;
    address public issuer;
    address public buyer1;
    address public buyer2;

    // 代币参数
    string public symbol = "MEME";
    uint256 public totalSupplyCap = 1000 * 10**18; // 1000 个代币
    uint256 public perMintAmount = 10 * 10**18;    // 每次铸造 10 个代币
    uint256 public pricePerMint = 0.1 ether;       // 每次铸造价格为 0.1 ETH

    // 常量
    uint256 public constant PROJECT_FEE_PERCENT = 1; // 项目方收取 1% 费用
    uint256 public constant BASIS_POINTS = 100;      // 百分比基点

    // 测试前的初始化
    function setUp() public {
        // 设置账户
        projectOwner = makeAddr("projectOwner");
        issuer = makeAddr("issuer");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");

        // 给买家提供足够的 ETH
        vm.deal(buyer1, 10 ether);
        vm.deal(buyer2, 10 ether);

        // 部署 MemeToken 实现合约
        implementation = new MemeToken();
        
        // 部署 MemeFactory 合约
        factory = new MemeFactory(address(implementation), projectOwner);
    }

    // 测试部署新的 Meme 代币
    function testDeployInscription() public {
        vm.startPrank(issuer);
        
        address tokenAddress = factory.deployInscription(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint
        );
        
        vm.stopPrank();
        
        // 验证 tokenAddress 非零
        assertTrue(tokenAddress != address(0), "Token address should not be zero");
        
        // 通过接口验证初始化参数
        IMemeToken memeToken = IMemeToken(tokenAddress);
        assertEq(memeToken.totalSupplyCap(), totalSupplyCap, "Total supply cap mismatch");
        assertEq(memeToken.perMintAmount(), perMintAmount, "Per mint amount mismatch");
        assertEq(memeToken.pricePerMint(), pricePerMint, "Price per mint mismatch");
        assertEq(memeToken.issuer(), issuer, "Issuer mismatch");
        assertEq(memeToken.totalMinted(), 0, "Initial total minted should be zero");
    }

    // 测试费用分配是否正确
    function testFeeDistribution() public {
        // 首先部署一个 Meme 代币
        vm.prank(issuer);
        address tokenAddress = factory.deployInscription(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint
        );
        
        // 记录铸造前的余额
        uint256 projectOwnerBalanceBefore = address(projectOwner).balance;
        uint256 issuerBalanceBefore = address(issuer).balance;
        
        // 买家铸造代币
        vm.prank(buyer1);
        factory.mintInscription{value: pricePerMint}(tokenAddress);
        
        // 计算预期的费用分配
        uint256 expectedProjectFee = (pricePerMint * PROJECT_FEE_PERCENT) / BASIS_POINTS;
        uint256 expectedIssuerFee = pricePerMint - expectedProjectFee;
        
        // 验证费用分配
        uint256 projectOwnerBalanceAfter = address(projectOwner).balance;
        uint256 issuerBalanceAfter = address(issuer).balance;
        
        assertEq(
            projectOwnerBalanceAfter - projectOwnerBalanceBefore,
            expectedProjectFee,
            "Project owner fee incorrect"
        );
        
        assertEq(
            issuerBalanceAfter - issuerBalanceBefore,
            expectedIssuerFee,
            "Issuer fee incorrect"
        );
    }

    // 测试每次铸造的代币数量是否正确
    function testMintAmount() public {
        // 部署 Meme 代币
        vm.prank(issuer);
        address tokenAddress = factory.deployInscription(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint
        );
        
        // 买家铸造代币
        vm.prank(buyer1);
        factory.mintInscription{value: pricePerMint}(tokenAddress);
        
        // 验证买家收到了正确数量的代币
        MemeToken token = MemeToken(tokenAddress);
        assertEq(token.balanceOf(buyer1), perMintAmount, "Buyer should receive perMintAmount tokens");
        assertEq(token.totalMinted(), perMintAmount, "Total minted should equal perMintAmount after one mint");
    }

    // 测试铸造不能超过总供应量上限
    function testCannotMintBeyondTotalSupply() public {
        // 部署一个总供应量小、每次铸造量较大的 Meme 代币
        uint256 smallTotalSupply = 100 * 10**18; // 100 个代币
        uint256 mintAmount = 50 * 10**18;       // 每次铸造 50 个代币
        
        vm.prank(issuer);
        address tokenAddress = factory.deployInscription(
            symbol,
            smallTotalSupply,
            mintAmount,
            pricePerMint
        );
        
        // 第一次铸造
        vm.prank(buyer1);
        factory.mintInscription{value: pricePerMint}(tokenAddress);
        
        // 第二次铸造
        vm.prank(buyer2);
        factory.mintInscription{value: pricePerMint}(tokenAddress);
        
        // 验证总铸造量
        MemeToken token = MemeToken(tokenAddress);
        assertEq(token.totalMinted(), smallTotalSupply, "Total minted should equal total supply cap");
        
        // 尝试第三次铸造，应该失败
        vm.prank(buyer1);
        vm.expectRevert("MemeFactory: Minting would exceed total supply cap");
        factory.mintInscription{value: pricePerMint}(tokenAddress);
    }

    // 测试免费铸造（价格为0）
    function testFreeMinting() public {
        // 部署价格为 0 的 Meme 代币
        uint256 freePrice = 0;
        
        vm.prank(issuer);
        address tokenAddress = factory.deployInscription(
            symbol,
            totalSupplyCap,
            perMintAmount,
            freePrice
        );
        
        // 买家铸造代币，不需要支付
        vm.prank(buyer1);
        factory.mintInscription{value: freePrice}(tokenAddress);
        
        // 验证买家收到了代币
        MemeToken token = MemeToken(tokenAddress);
        assertEq(token.balanceOf(buyer1), perMintAmount, "Buyer should receive tokens from free mint");
    }

    // 测试铸造时支付错误的金额
    function testIncorrectPaymentAmount() public {
        // 部署 Meme 代币
        vm.prank(issuer);
        address tokenAddress = factory.deployInscription(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint
        );
        
        // 尝试支付错误金额铸造
        vm.prank(buyer1);
        vm.expectRevert("MemeFactory: Incorrect payment amount");
        factory.mintInscription{value: 0.05 ether}(tokenAddress); // 支付的金额少于要求的金额
    }

    // 测试多次铸造直到达到供应上限
    function testMultipleMintingUntilCap() public {
        // 部署一个较小总供应量的 Meme 代币
        uint256 mintCount = 5; // 可以铸造 5 次
        uint256 smallMintAmount = 10 * 10**18; // 每次铸造 10 个代币
        uint256 smallTotalSupply = smallMintAmount * mintCount; // 总供应量为 50 个代币
        
        vm.prank(issuer);
        address tokenAddress = factory.deployInscription(
            symbol,
            smallTotalSupply,
            smallMintAmount,
            pricePerMint
        );
        
        // 进行 mintCount 次铸造
        for (uint256 i = 0; i < mintCount; i++) {
            vm.prank(buyer1);
            factory.mintInscription{value: pricePerMint}(tokenAddress);
        }
        
        // 验证总铸造量
        MemeToken token = MemeToken(tokenAddress);
        assertEq(token.totalMinted(), smallTotalSupply, "Total minted should equal total supply cap");
        
        // 再次铸造应该失败
        vm.prank(buyer1);
        vm.expectRevert("MemeFactory: Minting would exceed total supply cap");
        factory.mintInscription{value: pricePerMint}(tokenAddress);
    }
} 