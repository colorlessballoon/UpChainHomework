// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MemeToken
 * @dev 这是 ERC20 Meme 代币的基础实现合约。
 * 它被设计为通过 MemeFactory 使用最小代理 (Clones) 进行部署。
 * 代币名称固定为 "My Meme Token"。符号和其他参数在初始化时设置。
 */
contract MemeToken is ERC20 {
    // --- 状态变量 ---

    string private _initializedCustomSymbol; // 初始化后代币的自定义符号

    uint256 public totalSupplyCap;      // 代币总供应量上限
    uint256 public perMintAmount;       // 每次调用 mintInscription 时铸造的代币数量
    uint256 public pricePerMint;        // 每次铸造操作的价格 (以 wei 为单位)
    address public issuer;              // 此 Meme 代币的发行者地址 (创建者)
    address public projectFeeRecipient; // 项目方费用接收地址 (由工厂设置)
    address public factoryContract;     // 部署此代币实例的工厂合约地址 (授权铸造者)

    uint256 public totalMinted;         // 已铸造的代币总量，用于跟踪是否达到 totalSupplyCap

    bool private _isInitialized;        // 标志，确保 initialize 函数只被调用一次

    // --- 事件 ---

    /**
     * @dev 当代币被铸造时触发。
     * @param to 接收代币的地址。
     * @param amount 铸造的代币数量。
     */
    event TokensMinted(address indexed to, uint256 amount);

    // --- 构造函数 ---

    /**
     * @dev 基础实现合约的构造函数。
     * ERC20 的 name 和 symbol 设置为实现合约的占位符。
     * 代理合约将通过 initialize 设置其特定的 name 和 symbol。
     * 此构造函数仅在部署 MemeToken 的逻辑合约 (实现合约) 时调用一次。
     * 通过代理创建的实例不会直接调用此构造函数。
     */
    constructor() ERC20("My Meme Token Impl", "MMTI_IMPL") {
        // 此处无需特殊逻辑，因为主要状态通过 initialize 设置。
    }

    // --- 修改器 ---

    /**
     * @dev 确保合约实例已通过 initialize 函数进行初始化。
     */
    modifier onlyInitialized() {
        require(_isInitialized, "MemeToken: Not initialized"); // 检查：合约必须已初始化
        _;
    }
    
    /**
     * @dev 确保调用者是指定的工厂合约。
     * 只有工厂合约才有权调用 mint 函数。
     */
    modifier onlyFactory() {
        require(msg.sender == factoryContract, "MemeToken: Caller is not the factory"); // 检查：调用者必须是工厂合约
        _;
    }

    // --- 函数 ---

    /**
     * @dev 初始化 MemeToken 实例。
     * 此函数应在代理合约部署后由工厂合约调用一次。
     * @param symbolInput 代币的符号 (例如 "DOGE")。
     * @param totalSupplyCapInput 代币的总供应量上限。
     * @param perMintAmountInput 每次铸造操作允许铸造的数量。
     * @param pricePerMintInput 每次铸造操作的价格 (以 wei 为单位)。
     * @param issuerInput 此 Meme 代币的发行者地址。
     * @param projectFeeRecipientInput 项目方的费用接收地址。
     * @param factoryContractInput 部署此代币的工厂合约地址。
     */
    function initialize(
        string memory symbolInput,
        uint256 totalSupplyCapInput,
        uint256 perMintAmountInput,
        uint256 pricePerMintInput,
        address issuerInput,
        address projectFeeRecipientInput,
        address factoryContractInput
    ) external {
        require(!_isInitialized, "MemeToken: Already initialized"); // 防止重复初始化
        require(factoryContractInput != address(0), "MemeToken: Factory cannot be zero address"); // 工厂地址不能为零
        require(totalSupplyCapInput > 0, "MemeToken: Total supply cap must be > 0"); // 总供应量上限必须大于0
        require(perMintAmountInput > 0, "MemeToken: Per mint amount must be > 0"); // 每次铸造量必须大于0
        // 确保总供应量是每次铸造量的整数倍，这样可以完整铸造所有代币
        if (totalSupplyCapInput > 0 && perMintAmountInput > 0) { 
             require(totalSupplyCapInput % perMintAmountInput == 0, "MemeToken: Total supply must be a multiple of perMintAmount");
        }

        _initializedCustomSymbol = symbolInput;
        totalSupplyCap = totalSupplyCapInput;
        perMintAmount = perMintAmountInput;
        pricePerMint = pricePerMintInput;
        issuer = issuerInput;
        projectFeeRecipient = projectFeeRecipientInput;
        factoryContract = factoryContractInput;
        
        _isInitialized = true; //标记为已初始化
    }

    /**
     * @dev 返回代币的名称。对于所有 MemeToken 实例，名称固定。
     * @return string 代币名称 ("My Meme Token")。
     */
    function name() public view virtual override returns (string memory) {
        return "My Meme Token"; // 根据需求，代币名称固定
    }

    /**
     * @dev 返回代币的符号。
     * @return string 代币符号 (在 initialize 中设置)。
     */
    function symbol() public view virtual override onlyInitialized returns (string memory) {
        return _initializedCustomSymbol;
    }

    /**
     * @dev 返回代币的小数位数。默认为 18。
     * @return uint8 小数位数 (18)。
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev 铸造新的代币并将其分配给指定地址。
     * 只能由工厂合约调用 (通过 onlyFactory 修改器)。
     * 必须在合约初始化后调用 (通过 onlyInitialized 修改器)。
     * @param to 接收新铸造代币的地址。
     * @param amount 要铸造的代币数量，必须等于 perMintAmount。
     */
    function mint(address to, uint256 amount) external onlyInitialized onlyFactory {
        require(totalMinted + amount <= totalSupplyCap, "MemeToken: Mint amount exceeds total supply cap"); // 检查：铸造后不超过总供应上限
        require(amount == perMintAmount, "MemeToken: Must mint 'perMintAmount'"); // 检查：铸造数量必须等于预设的 perMintAmount

        totalMinted += amount; // 更新已铸造总量
        _mint(to, amount);     // 调用 OpenZeppelin ERC20 内部的 _mint 函数
        emit TokensMinted(to, amount); // 触发事件
    }
} 