"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const viem_1 = require("viem");
const accounts_1 = require("viem/accounts");
const chains_1 = require("viem/chains");
// 合约 ABI 和字节码
const contractAbi = [
    {
        inputs: [],
        stateMutability: 'nonpayable',
        type: 'constructor'
    }
];
// 这是编译后的合约字节码，实际情况下应该从编译输出中获取
const contractBytecode = '0x608060405234801561001057600080fd5b5060006100206000610113565b90506000600b905060005b8181101561010d5760405180606001604052806001830160f81b60ff1681526020016207a12063ffffffff1681526020016001831061007e57610083565b6001820b5b67016345785d8a000002815250600081908060018154018082558091505060019003906000526020600020906003020160009091909190915060008201518160000160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555060208201518160000160146101000a81548167ffffffffffffffff021916908367ffffffffffffffff16021790555060408201518160010155505080806001019150506100c7565b50506101a1565b60008082905060005b845181101561019757600084828151811061013a5761013961015e565b5b60209081029190910181015191909201600090815260209092200154821061016957600191505b8160011415610185578092508180610180906101a0565b9250505b8080610189906101a0565b91505061011c565b505092915050565b635b5e139f60e01b600052601260045260246000fd5b634e487b7160e01b600052601160045260246000fdfe';
// 部署合约函数
async function deployContract() {
    try {
        // 注意：这个私钥仅作示例，实际使用时应从环境变量加载并确保安全
        const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
        const account = (0, accounts_1.privateKeyToAccount)(privateKey);
        // 创建客户端
        const publicClient = (0, viem_1.createPublicClient)({
            chain: chains_1.sepolia,
            transport: (0, viem_1.http)('https://eth-sepolia.g.alchemy.com/v2/your-api-key')
        });
        const walletClient = (0, viem_1.createWalletClient)({
            account,
            chain: chains_1.sepolia,
            transport: (0, viem_1.http)('https://eth-sepolia.g.alchemy.com/v2/your-api-key')
        });
        console.log('开始部署合约...');
        // 部署合约
        const hash = await walletClient.deployContract({
            abi: contractAbi,
            bytecode: contractBytecode,
            account
        });
        console.log('交易哈希:', hash);
        // 等待交易完成
        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        console.log('合约已部署到地址:', receipt.contractAddress);
        console.log('Block number:', receipt.blockNumber);
        return receipt.contractAddress;
    }
    catch (error) {
        console.error('部署合约时发生错误:', error);
        throw error;
    }
}
// 运行部署函数
deployContract().catch(console.error);
