#!/usr/bin/env node
import { createWalletClient, http, parseEther, createPublicClient, formatEther, encodeFunctionData, parseGwei } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { sepolia } from 'viem/chains';
import dotenv from 'dotenv';
import readline from 'readline/promises';
import { randomBytes } from '@noble/hashes/utils'; // 更安全的随机数生成

dotenv.config();

const publicClient = createPublicClient({
  chain: sepolia,
  transport: http('https://sepolia.infura.io/v3/db160d45870e4d39802f6e030309f751'),
});

const walletClient = createWalletClient({
  chain: sepolia,
  transport: http('https://sepolia.infura.io/v3/db160d45870e4d39802f6e030309f751'),
});

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

// ERC20 ABI（包含transfer和balanceOf）
const erc20Abi = [
  {
    type: 'function',
    name: 'transfer',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'value', type: 'uint256' },
    ],
    outputs: [{ type: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
  },
];

async function mainMenu() {
  console.log('\n=== CLI 钱包 ===');
  console.log('1. 生成新私钥');
  console.log('2. 查询ETH余额');
  console.log('3. 查询ERC20余额');
  console.log('4. 发送ERC20转账');
  console.log('5. 退出');

  const choice = await rl.question('选择操作: ');
  switch (choice) {
    case '1': await generatePrivateKey(); break;
    case '2': await checkEthBalance(); break;
    case '3': await checkErc20Balance(); break;
    case '4': await sendErc20Transfer(); break;
    case '5': rl.close(); process.exit(0);
    default: console.log('无效选项'); await mainMenu();
  }
}

// 生成私钥（使用@noble/hashes）
async function generatePrivateKey() {
  const privateKey = `0x${Array.from(randomBytes(32)).map(b => b.toString(16).padStart(2, '0')).join('')}`;
  const account = privateKeyToAccount(privateKey);
  console.log('\n=== 新私钥已生成 ===');
  console.log('地址:', account.address);
  console.log('私钥:', privateKey);
  console.log('警告: 私钥一旦丢失将无法恢复！');
  await mainMenu();
}

// 查询ETH余额
async function checkEthBalance() {
  const address = await rl.question('输入地址: ');
  try {
    const balance = await publicClient.getBalance({ address });
    console.log(`余额: ${formatEther(balance)} ETH`);
  } catch (error) {
    console.log('查询失败:', error.message);
  }
  await mainMenu();
}

// 查询ERC20余额
async function checkErc20Balance() {
  const tokenAddress = await rl.question('输入ERC20合约地址: ');
  const userAddress = await rl.question('输入查询地址: ');
  try {
    const balance = await publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: 'balanceOf',
      args: [userAddress],
    });
    console.log(`余额: ${formatEther(balance)} 代币`);
  } catch (error) {
    console.log('查询失败:', error.message);
  }
  await mainMenu();
}

// 发送ERC20转账
async function sendErc20Transfer() {
  const privateKey = await rl.question('输入私钥: ');
  if (!privateKey.startsWith('0x')) {
    console.log('私钥必须以0x开头');
    return mainMenu();
  }

  try {
    const account = privateKeyToAccount(privateKey);
    const tokenAddress = await rl.question('输入ERC20合约地址: ');
    const toAddress = await rl.question('输入接收地址: ');
    const amount = await rl.question('输入转账数量: ');

    // 获取实时Gas价格
    const { maxPriorityFeePerGas, maxFeePerGas } = await publicClient.estimateFeesPerGas();

    const txHash = await walletClient.sendTransaction({
      account,
      to: tokenAddress,
      data: encodeFunctionData({
        abi: erc20Abi,
        functionName: 'transfer',
        args: [toAddress, parseEther(amount)],
      }),
      type: 'eip1559',
      maxPriorityFeePerGas: maxPriorityFeePerGas * 2n, // 提高小费加速交易
      maxFeePerGas: maxFeePerGas * 2n,
    });

    console.log('\n交易已发送:', txHash);
    console.log('浏览器链接: https://sepolia.etherscan.io/tx/' + txHash);
  } catch (error) {
    console.log('交易失败:', error.shortMessage || error.message);
  }
  await mainMenu();
}

mainMenu();