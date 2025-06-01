// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

// Mock Uniswap Router
contract MockUniswapRouter {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        // Mock successful liquidity addition
        return (amountTokenDesired, msg.value, 1);
    }

    function WETH() external pure returns (address) {
        return address(0);
    }
}

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    MemeToken public implementation;
    MockUniswapRouter public router;
    address public weth;
    address public projectFeeRecipient;
    address public user;
    uint256 public constant INITIAL_BALANCE = 100 ether;

    function setUp() public {
        // 部署实现合约
        implementation = new MemeToken();
        
        // 部署工厂合约
        router = new MockUniswapRouter();
        weth = makeAddr("weth");
        projectFeeRecipient = makeAddr("projectFeeRecipient");
        factory = new MemeFactory(
            address(implementation),
            projectFeeRecipient,
            address(router),
            weth
        );

        // 设置测试用户
        user = makeAddr("user");
        vm.deal(user, INITIAL_BALANCE);
    }

    function test_Deployment() public {
        assertEq(factory.memeTokenImplementation(), address(implementation));
        assertEq(factory.projectOwner(), projectFeeRecipient);
        assertEq(address(factory.uniswapRouter()), address(router));
        assertEq(address(factory.uniswapFactory()), weth);
    }

    function test_CreateMemeToken() public {
        string memory symbol = "DOGE";
        uint256 totalSupplyCap = 1000000 * 10**18;
        uint256 perMintAmount = 1000 * 10**18;
        uint256 pricePerMint = 0.1 ether;

        vm.startPrank(user);
        address tokenAddress = factory.deployInscription{value: 0.1 ether}(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint
        );
        vm.stopPrank();

        MemeToken token = MemeToken(tokenAddress);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupplyCap(), totalSupplyCap);
        assertEq(token.perMintAmount(), perMintAmount);
        assertEq(token.pricePerMint(), pricePerMint);
        assertEq(token.issuer(), user);
        assertEq(token.projectFeeRecipient(), projectFeeRecipient);
        assertEq(token.factoryContract(), address(factory));
    }

    function test_RevertWhen_CreateMemeTokenWithInsufficientFee() public {
        string memory symbol = "DOGE";
        uint256 totalSupplyCap = 1000000 * 10**18;
        uint256 perMintAmount = 1000 * 10**18;
        uint256 pricePerMint = 0.1 ether;

        vm.startPrank(user);
        vm.expectRevert();
        factory.deployInscription{value: 0.05 ether}(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint
        );
        vm.stopPrank();
    }

    function test_RevertWhen_CreateMemeTokenWithInvalidParameters() public {
        string memory symbol = "DOGE";
        uint256 totalSupplyCap = 1000000 * 10**18;
        uint256 perMintAmount = 1000 * 10**18;
        uint256 pricePerMint = 0.1 ether;

        vm.startPrank(user);
        vm.expectRevert();
        // 测试总供应量不是每次铸造量的整数倍
        factory.deployInscription{value: 0.1 ether}(
            symbol,
            totalSupplyCap + 1,
            perMintAmount,
            pricePerMint
        );
        vm.stopPrank();
    }

    function test_MintInscription() public {
        string memory symbol = "DOGE";
        uint256 totalSupplyCap = 1000000 * 10**18;
        uint256 perMintAmount = 1000 * 10**18;
        uint256 pricePerMint = 0.1 ether;

        vm.startPrank(user);
        address tokenAddress = factory.deployInscription{value: 0.1 ether}(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint
        );
        vm.stopPrank();

        MemeToken token = MemeToken(tokenAddress);
        
        // 铸造代币
        vm.startPrank(user);
        // 先批准工厂合约使用代币
        token.approve(address(factory), perMintAmount);
        factory.mintInscription{value: pricePerMint}(tokenAddress);
        vm.stopPrank();

        // 验证铸造结果
        assertEq(token.balanceOf(user), 0); // 用户余额应该为0，因为代币被用于添加流动性
        assertEq(token.totalMinted(), perMintAmount);

        // 验证项目方收到的费用
        uint256 expectedProjectFee = (pricePerMint * 5) / 100; // 5% 的项目方费用
        assertEq(projectFeeRecipient.balance, expectedProjectFee);
    }

    function test_RevertWhen_MintInscriptionWithInsufficientPayment() public {
        string memory symbol = "DOGE";
        uint256 totalSupplyCap = 1000000 * 10**18;
        uint256 perMintAmount = 1000 * 10**18;
        uint256 pricePerMint = 0.1 ether;

        vm.startPrank(user);
        address tokenAddress = factory.deployInscription{value: 0.1 ether}(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint
        );
        vm.stopPrank();

        // 尝试用不足的支付铸造
        vm.startPrank(user);
        vm.expectRevert();
        factory.mintInscription{value: pricePerMint - 0.01 ether}(tokenAddress);
        vm.stopPrank();
    }

    function test_RevertWhen_MintInscriptionExceedingTotalSupply() public {
        string memory symbol = "DOGE";
        uint256 totalSupplyCap = 1000 * 10**18;
        uint256 perMintAmount = 1000 * 10**18;
        uint256 pricePerMint = 0.1 ether;

        vm.startPrank(user);
        address tokenAddress = factory.deployInscription{value: 0.1 ether}(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint
        );
        vm.stopPrank();

        MemeToken token = MemeToken(tokenAddress);
        
        // 第一次铸造
        vm.startPrank(user);
        token.approve(address(factory), perMintAmount);
        factory.mintInscription{value: pricePerMint}(tokenAddress);
        vm.stopPrank();

        // 验证第一次铸造结果
        assertEq(token.balanceOf(user), 0); // 用户余额应该为0，因为代币被用于添加流动性
        assertEq(token.totalMinted(), perMintAmount);

        // 尝试第二次铸造，应该失败
        vm.startPrank(user);
        vm.expectRevert();
        factory.mintInscription{value: pricePerMint}(tokenAddress);
        vm.stopPrank();
    }

    function test_WithdrawFees() public {
        string memory symbol = "DOGE";
        uint256 totalSupplyCap = 1000000 * 10**18;
        uint256 perMintAmount = 1000 * 10**18;
        uint256 pricePerMint = 0.1 ether;

        vm.startPrank(user);
        address tokenAddress = factory.deployInscription{value: 0.1 ether}(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint
        );
        vm.stopPrank();

        MemeToken token = MemeToken(tokenAddress);
        
        // 铸造代币
        vm.startPrank(user);
        token.approve(address(factory), perMintAmount);
        factory.mintInscription{value: pricePerMint}(tokenAddress);
        vm.stopPrank();

        // 验证铸造结果
        assertEq(token.balanceOf(user), 0); // 用户余额应该为0，因为代币被用于添加流动性
        assertEq(token.totalMinted(), perMintAmount);

        // 验证项目方收到的铸造费用
        uint256 expectedMintFee = (pricePerMint * 5) / 100; // 5% 的项目方费用
        assertEq(projectFeeRecipient.balance, expectedMintFee);

        // 提取部署费用，必须由 projectFeeRecipient 调用
        uint256 balanceBefore = projectFeeRecipient.balance;
        vm.startPrank(projectFeeRecipient);
        factory.withdrawFees();
        vm.stopPrank();
        uint256 balanceAfter = projectFeeRecipient.balance;

        // 验证提取的部署费用
        uint256 expectedDeploymentFee = 0.1 ether; // 部署费用
        assertEq(balanceAfter - balanceBefore, expectedDeploymentFee);
    }

    function test_RevertWhen_WithdrawFeesByNonOwner() public {
        vm.startPrank(user);
        vm.expectRevert();
        factory.withdrawFees();
        vm.stopPrank();
    }
} 