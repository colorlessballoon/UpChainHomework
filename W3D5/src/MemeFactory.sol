// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MemeToken.sol"; // 引入 MemeToken 合约，用于类型转换和获取接口信息

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
    
    // 项目方收取的费用百分比 (例如 1 表示 1%)
    uint256 public constant projectFeePercent = 1; 
    // 用于百分比计算的基点 (100 表示百分比的分母)
    uint256 public constant basisPoints = 100;

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

    // --- 构造函数 ---

    /**
     * @dev MemeFactory 的构造函数。
     * @param _memeTokenImplementation MemeToken 逻辑合约的地址。
     * @param _projectOwner 项目方的地址。
     */
    constructor(address _memeTokenImplementation, address _projectOwner) {
        require(_memeTokenImplementation != address(0), "MemeFactory: Invalid implementation address"); // 实现合约地址不能为空
        require(_projectOwner != address(0), "MemeFactory: Invalid project owner address");       // 项目方地址不能为空
        memeTokenImplementation = _memeTokenImplementation;
        projectOwner = _projectOwner;
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
    ) external returns (address tokenAddress) {
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

        emit MemeDeployed(tokenAddress, currentIssuer, symbol, totalSupplyCap, perMintAmount, pricePerMint); // 触发部署事件
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

        require(msg.value == currentPrice, "MemeFactory: Incorrect payment amount"); // 检查支付的 ETH 是否等于价格
        require(amountToMint > 0, "MemeFactory: perMintAmount must be > 0");     // 确保每次铸造量有效 (应由 deployInscription 保证)

        // 在进行任何状态更改或外部调用之前，检查是否可以铸造 (遵循 Checks-Effects-Interactions 模式)
        uint256 currentTotalMinted = memeToken.totalMinted();
        uint256 currentSupplyCap = memeToken.totalSupplyCap();
        require(currentTotalMinted + amountToMint <= currentSupplyCap, "MemeFactory: Minting would exceed total supply cap"); // 检查是否会超出总供应量上限

        // 调用 MemeToken 代理合约的 mint 函数为 msg.sender 铸造代币
        // 注意：这是对外部合约的调用
        memeToken.mint(msg.sender, amountToMint);

        // 如果价格大于0，则分配费用
        if (currentPrice > 0) {
            uint256 projectShare = (currentPrice * projectFeePercent) / basisPoints; // 计算项目方份额 (1%)
            uint256 issuerShare = currentPrice - projectShare;                      // 计算 Meme 发行者份额 (剩余部分)

            // 发送项目方费用份额 (如果大于0)
            if (projectShare > 0) {
                (bool successProject, ) = payable(projectOwner).call{value: projectShare}("");
                require(successProject, "MemeFactory: Failed to send fee to project owner"); // 检查 ETH 转账是否成功
            }
            // 发送 Meme 发行者费用份额 (如果大于0)
            // 即使 projectShare 因取整为0，发行者也应获得其份额
            if (issuerShare > 0) {
                (bool successIssuer, ) = payable(memeIssuer).call{value: issuerShare}("");
                require(successIssuer, "MemeFactory: Failed to send fee to meme issuer"); // 检查 ETH 转账是否成功
            }
            emit FeeDistributed(tokenAddr, msg.sender, currentPrice, projectShare, issuerShare); // 触发费用分配事件
        } else {
            // 如果价格为0 (免费铸造)，也触发事件，但份额为0
            emit FeeDistributed(tokenAddr, msg.sender, 0, 0, 0);
        }
    }
} 