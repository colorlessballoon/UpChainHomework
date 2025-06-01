// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MemeToken.sol"; // 引入 MemeToken 合约，用于类型转换和获取接口信息
import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/TransferHelper.sol";

/**
 * @title IMemeToken
 * @dev MemeToken 合约的接口，用于工厂合约与通过代理创建的 MemeToken 实例进行交互。
 * 包含了 initialize, mint 以及一些状态变量的 getter 函数。
 */
interface IMemeToken {
    // --- 外部函数 ---

    /**
     * @dev 初始化 MemeToken 实例的函数接口。
     */
    function initialize(
        string memory symbolInput,
        uint256 totalSupplyCapInput,
        uint256 perMintAmountInput,
        uint256 pricePerMintInput,
        address issuerInput,
        address projectFeeRecipientInput,
        address factoryContractInput
    ) external;

    /**
     * @dev 铸造代币的函数接口。
     */
    function mint(address to, uint256 amount) external;
    
    // --- 视图函数 (Getter) ---

    /** @dev 获取代币总供应量上限。 */
    function totalSupplyCap() external view returns (uint256);
    /** @dev 获取每次铸造的数量。 */
    function perMintAmount() external view returns (uint256);
    /** @dev 获取每次铸造的价格。 */
    function pricePerMint() external view returns (uint256);
    /** @dev 获取此 Meme 代币的发行者。 */
    function issuer() external view returns (address);
    /** @dev 获取已铸造的代币总量。 */
    function totalMinted() external view returns (uint256);
    // 注意: projectFeeRecipient() 和 factoryContract() 的 getter 虽然存在于 MemeToken 中，
    // 但工厂合约自身已存储这些信息或可以直接推断，故接口中未显式列出。
}

/**
 * @title MemeFactory
 * @dev 此工厂合约用于通过最小代理模式 (EIP-1167 Clones) 部署 MemeToken (ERC20) 实例。
 * 旨在降低 Meme 发行者的 Gas 成本。
 */
contract MemeFactory {
    // --- 状态变量 ---

    address public immutable memeTokenImplementation; // MemeToken 逻辑合约 (实现合约) 的地址
    address public immutable projectOwner;          // 项目方地址，用于接收部分铸造费用
    IUniswapV2Router02 public immutable uniswapRouter;
    IUniswapV2Factory public immutable uniswapFactory;
    
    // 项目方收取的费用百分比 (例如 1 表示 1%)
    uint256 public constant projectFeePercent = 5; 
    // 用于百分比计算的基点 (100 表示百分比的分母)
    uint256 public constant basisPoints = 100;

    // 存储每个代币的初始价格
    mapping(address => uint256) public initialPrices;

    // --- 事件 ---

    /**
     * @dev 当一个新的 MemeToken 代理合约被部署时触发。
     * @param tokenAddress 新部署的 MemeToken 代理合约地址。
     * @param issuer Meme 代币的发行者 (调用 deployInscription 的用户)。
     * @param symbol 代币的符号。
     * @param totalSupplyCap 代币总供应量上限。
     * @param perMintAmount 每次铸造的数量。
     * @param pricePerMint 每次铸造的价格。
     */
    event MemeDeployed(
        address indexed tokenAddress,
        address indexed issuer,
        string symbol,
        uint256 totalSupplyCap,
        uint256 perMintAmount,
        uint256 pricePerMint
    );

    /**
     * @dev 当一次 Meme 铸造的费用被成功分配时触发。
     * @param tokenAddress 相关的 MemeToken 合约地址。
     * @param buyer 购买 Meme 的用户地址。
     * @param totalFeePaid 用户支付的总费用。
     * @param projectShare 分配给项目方的费用份额。
     * @param issuerShare 分配给 Meme 发行者的费用份额。
     */
    event FeeDistributed(
        address indexed tokenAddress,
        address indexed buyer,
        uint256 totalFeePaid,
        uint256 projectShare,
        uint256 issuerShare
    );

    event LiquidityAdded(
        address indexed tokenAddress,
        uint256 ethAmount,
        uint256 tokenAmount
    );

    // --- 构造函数 ---

    /**
     * @dev MemeFactory 的构造函数。
     * @param _memeTokenImplementation MemeToken 逻辑合约的地址。
     * @param _projectOwner 项目方的地址。
     * @param _uniswapRouter Uniswap V2 Router 合约地址。
     * @param _uniswapFactory Uniswap V2 Factory 合约地址。
     */
    constructor(
        address _memeTokenImplementation,
        address _projectOwner,
        address _uniswapRouter,
        address _uniswapFactory
    ) {
        require(_memeTokenImplementation != address(0), "MemeFactory: Invalid implementation address"); // 实现合约地址不能为空
        require(_projectOwner != address(0), "MemeFactory: Invalid project owner address");       // 项目方地址不能为空
        require(_uniswapRouter != address(0), "MemeFactory: Invalid router address");
        require(_uniswapFactory != address(0), "MemeFactory: Invalid factory address");
        memeTokenImplementation = _memeTokenImplementation;
        projectOwner = _projectOwner;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        uniswapFactory = IUniswapV2Factory(_uniswapFactory);
    }

    // --- 外部函数 ---

    /**
     * @dev Meme 发行者调用此方法来创建并部署一个新的 MemeToken ERC20 合约实例 (代理)。
     * @param symbol 新创建代币的代号 (例如 "MEME")。
     * @param totalSupplyCap 代币的总发行量。
     * @param perMintAmount 每次调用 mintInscription 时铸造的 Meme 数量。
     * @param pricePerMint 每个 Meme 铸造时需要支付的费用 (以 wei 计价)。
     * @return tokenAddress 新部署的 MemeToken 代理合约的地址。
     */
    function deployInscription(
        string memory symbol,
        uint256 totalSupplyCap,
        uint256 perMintAmount,
        uint256 pricePerMint
    ) external payable returns (address tokenAddress) {
        require(msg.value >= 0.1 ether, "MemeFactory: Insufficient deployment fee");
        require(totalSupplyCap > 0, "MemeFactory: Total supply cap must be > 0");             // 总供应量必须大于0
        require(perMintAmount > 0, "MemeFactory: Per mint amount must be > 0");            // 每次铸造量必须大于0
        require(totalSupplyCap % perMintAmount == 0, "MemeFactory: Total supply not multiple of perMintAmount"); // 总供应量必须是每次铸造量的整数倍
        // pricePerMint 可以为 0，允许免费铸造

        address currentIssuer = msg.sender; // Meme 发行者是调用此函数的用户
        
        // 使用 OpenZeppelin Clones 库创建最小代理合约
        tokenAddress = Clones.clone(memeTokenImplementation);

        // 调用新创建的代理合约的 initialize 函数来设置其状态
        IMemeToken(tokenAddress).initialize(
            symbol,
            totalSupplyCap,
            perMintAmount,
            pricePerMint,
            currentIssuer,      // Meme 发行者
            projectOwner,       // 项目方费用接收地址
            address(this)       // 本工厂合约地址 (作为授权的铸造者)
        );

        // 存储初始价格
        initialPrices[tokenAddress] = pricePerMint;

        emit MemeDeployed(tokenAddress, currentIssuer, symbol, totalSupplyCap, perMintAmount, pricePerMint); // 触发部署事件
    }

    // 添加流动性到Uniswap
    function _addLiquidity(address tokenAddress, uint256 ethAmount, uint256 tokenAmount) internal {
        TransferHelper.safeTransferFrom(tokenAddress, msg.sender, address(this), tokenAmount);
        TransferHelper.safeApprove(tokenAddress, address(uniswapRouter), tokenAmount);
        
        // 添加流动性
        uniswapRouter.addLiquidityETH{value: ethAmount}(
            tokenAddress,
            tokenAmount,
            tokenAmount, // 最小token数量
            ethAmount,   // 最小ETH数量
            address(this), // 接收LP代币的地址
            block.timestamp + 15 minutes
        );

        emit LiquidityAdded(tokenAddress, ethAmount, tokenAmount);
    }

    // 从Uniswap获取当前价格
    function _getCurrentPrice(address tokenAddress) internal view returns (uint256) {
        address pair = uniswapFactory.getPair(tokenAddress, uniswapRouter.WETH());
        if (pair == address(0)) return initialPrices[tokenAddress];

        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        if (reserve0 == 0 || reserve1 == 0) return initialPrices[tokenAddress];

        // 计算价格（以ETH计价）
        if (IUniswapV2Pair(pair).token0() == tokenAddress) {
            return (uint256(reserve1) * 1e18) / uint256(reserve0);
        } else {
            return (uint256(reserve0) * 1e18) / uint256(reserve1);
        }
    }

    /**
     * @dev 购买 Meme 的用户调用此函数进行铸造。
     * 用户需支付相应的费用 (如果 pricePerMint > 0)。
     * 费用按比例分配给 Meme 发行者和项目方。
     * @param tokenAddr 要铸造的 MemeToken 合约地址 (代理合约地址)。
     */
    function mintInscription(address tokenAddr) external payable {
        require(tokenAddr != address(0), "MemeFactory: Invalid token address"); // 代币地址不能为空
        IMemeToken memeToken = IMemeToken(tokenAddr); // 获取 MemeToken 实例的接口

        uint256 currentPrice = memeToken.pricePerMint();      // 获取此 Meme 的铸造价格
        uint256 amountToMint = memeToken.perMintAmount();    // 获取每次铸造的数量
        address memeIssuer = memeToken.issuer();             // 获取此 Meme 的发行者地址

        require(msg.value >= currentPrice, "MemeFactory: Insufficient payment"); // 检查支付的 ETH 是否等于价格
        require(amountToMint > 0, "MemeFactory: perMintAmount must be > 0");     // 确保每次铸造量有效 (应由 deployInscription 保证)

        // 在进行任何状态更改或外部调用之前，检查是否可以铸造 (遵循 Checks-Effects-Interactions 模式)
        uint256 currentTotalMinted = memeToken.totalMinted();
        uint256 currentSupplyCap = memeToken.totalSupplyCap();
        require(currentTotalMinted + amountToMint <= currentSupplyCap, "MemeFactory: Minting would exceed total supply cap"); // 检查是否会超出总供应量上限

        // 计算费用分配
        uint256 projectShare = (currentPrice * projectFeePercent) / basisPoints; // 计算项目方份额 (5%)
        uint256 liquidityShare = currentPrice - projectShare;                    // 计算流动性份额 (95%)

        // 铸造代币给用户
        memeToken.mint(msg.sender, amountToMint);

        // 将代币转移到工厂合约用于添加流动性
        TransferHelper.safeTransferFrom(tokenAddr, msg.sender, address(this), amountToMint);
        
        // 批准 Uniswap Router 使用代币
        TransferHelper.safeApprove(tokenAddr, address(uniswapRouter), amountToMint);

        // 添加流动性
        uniswapRouter.addLiquidityETH{value: liquidityShare}(
            tokenAddr,
            amountToMint,
            amountToMint, // 最小token数量
            liquidityShare, // 最小ETH数量
            msg.sender, // LP代币给用户
            block.timestamp + 15 minutes
        );

        // 发送项目方费用
        if (projectShare > 0) {
            (bool successProject, ) = payable(projectOwner).call{value: projectShare}("");
            require(successProject, "MemeFactory: Failed to send fee to project owner");
        }

        emit FeeDistributed(tokenAddr, msg.sender, currentPrice, projectShare, liquidityShare);
        emit LiquidityAdded(tokenAddr, liquidityShare, amountToMint);
    }

    // 新增：用户主动添加流动性
    function addLiquidity(address tokenAddress, uint256 ethAmount, uint256 tokenAmount) external payable {
        require(tokenAddress != address(0), "MemeFactory: Invalid token address");
        require(ethAmount > 0 && tokenAmount > 0, "MemeFactory: Amounts must be > 0");
        require(msg.value >= ethAmount, "MemeFactory: Insufficient ETH amount");
        
        // 用户必须提前 approve 工厂合约
        TransferHelper.safeTransferFrom(tokenAddress, msg.sender, address(this), tokenAmount);
        TransferHelper.safeApprove(tokenAddress, address(uniswapRouter), tokenAmount);
        
        // 添加流动性
        uniswapRouter.addLiquidityETH{value: ethAmount}(
            tokenAddress,
            tokenAmount,
            tokenAmount, // 最小token数量
            ethAmount,   // 最小ETH数量
            msg.sender, // LP 归用户所有
            block.timestamp + 15 minutes
        );

        // 如果有剩余的 ETH，返还给用户
        if (msg.value > ethAmount) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - ethAmount}("");
            require(success, "MemeFactory: Failed to refund excess ETH");
        }

        emit LiquidityAdded(tokenAddress, ethAmount, tokenAmount);
    }

    // 新增：从Uniswap购买Meme
    function buyMeme(address tokenAddr) external payable {
        require(tokenAddr != address(0), "MemeFactory: Invalid token address");
        IMemeToken memeToken = IMemeToken(tokenAddr);

        // 获取当前Uniswap价格
        uint256 currentPrice = _getCurrentPrice(tokenAddr);
        uint256 mintPrice = memeToken.pricePerMint();

        // 确保Uniswap价格优于mint价格
        require(currentPrice < mintPrice, "MemeFactory: Uniswap price not better than mint price");

        // 计算可以购买的代币数量
        uint256 amountToBuy = (msg.value * 1e18) / currentPrice;
        uint256 perMintAmount = memeToken.perMintAmount();

        // 确保购买数量是perMintAmount的整数倍
        amountToBuy = (amountToBuy / perMintAmount) * perMintAmount;
        require(amountToBuy > 0, "MemeFactory: Insufficient payment amount");

        // 检查总供应量限制
        uint256 currentTotalMinted = memeToken.totalMinted();
        uint256 currentSupplyCap = memeToken.totalSupplyCap();
        require(currentTotalMinted + amountToBuy <= currentSupplyCap, "MemeFactory: Buying would exceed total supply cap");

        // 铸造代币
        memeToken.mint(msg.sender, amountToBuy);

        // 计算实际使用的ETH数量
        uint256 actualEthUsed = (amountToBuy * currentPrice) / 1e18;
        
        // 如果有剩余的ETH，返还给用户
        if (msg.value > actualEthUsed) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - actualEthUsed}("");
            require(success, "MemeFactory: Failed to refund excess ETH");
        }
    }

    function withdrawFees() external {
        require(msg.sender == projectOwner, "MemeFactory: Only project owner can withdraw fees");
        // 只提取部署费用，铸造费用已经在铸造时直接发送给项目方
        uint256 deploymentFees = address(this).balance;
        require(deploymentFees > 0, "MemeFactory: No fees to withdraw");
        (bool success, ) = projectOwner.call{value: deploymentFees}("");
        require(success, "MemeFactory: Fee withdrawal failed");
    }

    // 允许合约接收ETH
    receive() external payable {}
} 