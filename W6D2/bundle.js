// 加载环境变量
require("dotenv").config();

// 引入 ethers.js，用于以太坊交互
const { ethers } = require("ethers");

// 引入 Flashbots Bundle Provider，用于发送交易包
const {
  FlashbotsBundleProvider
} = require("@flashbots/ethers-provider-bundle");

// NFT 合约地址（部署在 Sepolia 测试网）
const NFT_CONTRACT_ADDRESS = "0xb3b777e95AAADa77d93156412A1397C95ABb7A8F";

// 定义合约的 ABI（仅包括我们会调用的函数）
const NFT_ABI = [
  "function enablePresale() external",             // 启用预售
  "function presale(uint256 amount) external payable"  // 用户参与预售，支付 ETH
];

const main = async () => {
  try {
    // 创建 JSON RPC 提供者，连接到以太坊节点（Sepolia）
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);

    // 创建两个钱包实例：项目方 (Owner) 和 用户 (User)
    const walletOwner = new ethers.Wallet(process.env.PRIVATE_KEY_OWNER, provider);
    const walletUser = new ethers.Wallet(process.env.PRIVATE_KEY_USER, provider);

    // 创建 Flashbots 提供者实例，用于发送打包交易
    const flashbotsProvider = await FlashbotsBundleProvider.create(
      provider,
      walletOwner, // 用于签名 Flashbots 请求的账户
      "https://relay-sepolia.flashbots.net", // Sepolia 的 Flashbots 中继器地址
      "sepolia" // 网络名称
    );

    // 初始化 NFT 合约对象
    const nft = new ethers.Contract(NFT_CONTRACT_ADDRESS, NFT_ABI, provider);

    // 获取当前最新区块号
    const latestBlock = await provider.getBlockNumber();

    // 获取当前网络的 gas 费用数据
    const feeData = await provider.getFeeData();
    const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas * 5n; // 提高优先费（小费），提高打包几率
    const maxFeePerGas = feeData.maxFeePerGas * 2n; // 提高总费用上限

    // 构造 enablePresale 交易（项目方调用）
    const enablePresaleTx = await nft.connect(walletOwner).enablePresale.populateTransaction();
    enablePresaleTx.to = NFT_CONTRACT_ADDRESS;
    enablePresaleTx.from = walletOwner.address;
    enablePresaleTx.nonce = await provider.getTransactionCount(walletOwner.address); // 设置 nonce
    enablePresaleTx.chainId = 11155111; // Sepolia 的 chainId
    enablePresaleTx.maxPriorityFeePerGas = maxPriorityFeePerGas;
    enablePresaleTx.maxFeePerGas = maxFeePerGas;
    enablePresaleTx.gasLimit = 500000n;

    // 构造 presale 交易（用户调用）
    const presaleTx = await nft.connect(walletUser).presale.populateTransaction(1);
    presaleTx.to = NFT_CONTRACT_ADDRESS;
    presaleTx.from = walletUser.address;
    presaleTx.value = ethers.parseEther("0.01"); // 用户支付 0.01 ETH
    presaleTx.nonce = await provider.getTransactionCount(walletUser.address); // 设置 nonce
    presaleTx.chainId = 11155111;
    presaleTx.maxPriorityFeePerGas = maxPriorityFeePerGas;
    presaleTx.maxFeePerGas = maxFeePerGas;
    presaleTx.gasLimit = 500000n;

    // 构建交易包：先启用预售，再参与预售
    const bundle = [
      {
        signer: walletOwner,
        transaction: enablePresaleTx
      },
      {
        signer: walletUser,
        transaction: presaleTx
      }
    ];

    // 目标区块号（2 个区块之后）
    const targetBlock = latestBlock + 2;

    // 向 Flashbots 中继器发送交易包
    const bundleResponse = await flashbotsProvider.sendBundle(bundle, targetBlock);

    if ("error" in bundleResponse) {
      // 如果返回结果中包含 error 字段，表示发送失败
      console.error("❌ 交易包发送错误:", bundleResponse.error.message);
      return;
    }

    console.log("✅ 交易包已发送到 Flashbots 中继器，等待被打包...");
    console.log("💰 Gas 费用设置:");
    console.log(`  最大优先费用（小费）: ${ethers.formatUnits(maxPriorityFeePerGas, "gwei")} Gwei`);
    console.log(`  最大总费用: ${ethers.formatUnits(maxFeePerGas, "gwei")} Gwei`);

    // 等待交易包是否被成功打包
    const resolution = await bundleResponse.wait();
    if (resolution === 0) {
      console.log("✅ 交易包已被打包到区块", targetBlock);
    } else if (resolution === 1) {
      console.log("⏳ 交易包尚未被打包到目标区块");
    } else {
      console.log("❌ 交易包被丢弃");
    }

    // 如果有 bundleHash，可以获取交易包统计信息
    if (bundleResponse.bundleHash) {
      const stats = await flashbotsProvider.getBundleStats(bundleResponse.bundleHash, targetBlock);
      console.log("📊 Flashbots 交易包统计信息:");
      console.dir(stats, { depth: null });
    }

  } catch (error) {
    console.error("❌ 发生错误:", error);
  }
};

// 运行主函数
main();