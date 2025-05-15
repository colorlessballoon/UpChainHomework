import { useState, useEffect } from 'react'
import {
  createPublicClient, createWalletClient, http, parseEther, formatEther,
  getContract, hexToString, getAddress
} from 'viem'
import { sepolia } from 'viem/chains'
import { custom } from 'viem'
import { TOKEN_BANK_ADDRESS, TOKEN_BANK_ABI } from './constants'
import { ERC20_ABI } from './erc20-abi'

function App() {
  const [account, setAccount] = useState(null)
  const [tokenAddress, setTokenAddress] = useState('')
  const [tokenBalance, setTokenBalance] = useState('0')
  const [depositAmount, setDepositAmount] = useState('')
  const [bankBalance, setBankBalance] = useState('0')
  const [tokenSymbol, setTokenSymbol] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [txHash, setTxHash] = useState('')

  // 确保合约地址格式正确
  const formattedTokenBankAddress = TOKEN_BANK_ADDRESS.startsWith('0x') 
    ? TOKEN_BANK_ADDRESS 
    : `0x${TOKEN_BANK_ADDRESS}`;

  // 创建公共客户端
  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http()
  })

  // 初始化
  useEffect(() => {
    const connectWallet = async () => {
      if (window.ethereum) {
        try {
          // 请求连接钱包
          const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' })
          setAccount(accounts[0])

          // 设置帐户变更监听
          window.ethereum.on('accountsChanged', (newAccounts) => {
            setAccount(newAccounts[0])
          })

          // 确保用户连接到Sepolia测试网
          const chainId = await window.ethereum.request({ method: 'eth_chainId' })
          console.log("当前网络ChainId:", chainId);
          if (chainId !== '0xaa36a7') { // Sepolia的chainId是0xaa36a7
            try {
              // 尝试切换到Sepolia网络
              await window.ethereum.request({
                method: 'wallet_switchEthereumChain',
                params: [{ chainId: '0xaa36a7' }],
              })
            } catch (switchError) {
              // 如果用户没有Sepolia网络，帮助他们添加
              if (switchError.code === 4902) {
                try {
                  await window.ethereum.request({
                    method: 'wallet_addEthereumChain',
                    params: [
                      {
                        chainId: '0xaa36a7',
                        chainName: 'Sepolia Test Network',
                        nativeCurrency: {
                          name: 'ETH',
                          symbol: 'ETH',
                          decimals: 18
                        },
                        rpcUrls: ['https://rpc.sepolia.org'],
                        blockExplorerUrls: ['https://sepolia.etherscan.io'],
                      },
                    ],
                  })
                } catch (addError) {
                  console.error('添加Sepolia网络失败:', addError)
                  setError('请手动切换到Sepolia测试网')
                }
              } else {
                console.error('切换网络失败:', switchError)
                setError('请手动切换到Sepolia测试网')
              }
            }
          }
        } catch (err) {
          console.error('连接钱包失败:', err)
          setError('连接钱包失败')
        }
      } else {
        setError('请安装MetaMask!')
      }
    }

    connectWallet()
  }, [])

  // 获取Token合约地址
  useEffect(() => {
    const getTokenAddress = async () => {
      if (!account) return

      try {
        // 尝试直接使用ethereum来调用合约
        const data = '0xfc0c546a'; // token() 函数的签名
        console.log("调用合约地址:", formattedTokenBankAddress);
        const result = await window.ethereum.request({
          method: 'eth_call',
          params: [
            {
              to: formattedTokenBankAddress,
              data: data,
            },
            'latest',
          ],
        });
        
        // 结果是一个32字节的值，需要提取地址部分
        const address = `0x${result.slice(26)}`;
        const checksumAddress = getAddress(address); // 确保地址是校验和格式
        setTokenAddress(checksumAddress);
        console.log("代币地址:", checksumAddress);
      } catch (err) {
        console.error('获取代币地址失败:', err)
        setError('获取代币地址失败')
      }
    }

    getTokenAddress()
  }, [account, formattedTokenBankAddress])

  // 刷新代币和存款余额的函数
  const refreshBalances = async () => {
    if (!account || !tokenAddress) return;

    try {
      console.log("开始刷新余额...");
      // 获取用户余额
      const balanceData = `0x70a08231000000000000000000000000${account.slice(2)}`; // balanceOf(address) 函数
      const balanceResult = await window.ethereum.request({
        method: 'eth_call',
        params: [
          {
            to: tokenAddress,
            data: balanceData,
          },
          'latest',
        ],
      });
      
      // 解析余额
      const balance = BigInt(balanceResult);
      console.log("代币余额原始值:", balanceResult, "解析后:", formatEther(balance));
      setTokenBalance(formatEther(balance));
      
      // 获取存款余额
      const depositData = `0x27e235e3000000000000000000000000${account.slice(2)}`; // balances(address) 函数
      const depositResult = await window.ethereum.request({
        method: 'eth_call',
        params: [
          {
            to: formattedTokenBankAddress,
            data: depositData,
          },
          'latest',
        ],
      });
      
      // 解析存款余额
      const depositBalance = BigInt(depositResult);
      console.log("存款余额原始值:", depositResult, "解析后:", formatEther(depositBalance));
      setBankBalance(formatEther(depositBalance));
      console.log("余额刷新完成!");
    } catch (err) {
      console.error('刷新余额失败:', err);
      setError('刷新余额失败: ' + (err.message || err));
    }
  };

  // 获取Token信息
  useEffect(() => {
    const getTokenInfo = async () => {
      if (!account || !tokenAddress) return

      try {
        // 获取代币符号
        const symbolData = '0x95d89b41'; // symbol() 函数的签名
        const symbolResult = await window.ethereum.request({
          method: 'eth_call',
          params: [
            {
              to: tokenAddress,
              data: symbolData,
            },
            'latest',
          ],
        });
        
        // 解析字符串结果
        const hexLength = parseInt(symbolResult.slice(66, 130), 16);
        const symbol = hexToString(`0x${symbolResult.slice(130, 130 + hexLength * 2)}`);
        setTokenSymbol(symbol);
        console.log("代币符号:", symbol);
        
        // 刷新余额
        await refreshBalances();
      } catch (err) {
        console.error('获取代币信息失败:', err)
        setError('获取代币信息失败: ' + (err.message || err))
      }
    }

    getTokenInfo()
  }, [account, tokenAddress, formattedTokenBankAddress])

  // 等待交易确认的辅助函数
  const waitForTransactionReceipt = async (txHash) => {
    console.log(`等待交易确认: ${txHash}`);
    let receipt = null;
    let attempts = 0;
    const maxAttempts = 30; // 最多等待30次

    while (!receipt && attempts < maxAttempts) {
      try {
        receipt = await window.ethereum.request({
          method: 'eth_getTransactionReceipt',
          params: [txHash],
        });
        
        if (!receipt) {
          attempts++;
          console.log(`尝试 ${attempts}/${maxAttempts} - 交易仍在处理中...`);
          await new Promise(resolve => setTimeout(resolve, 2000)); // 等待2秒
        }
      } catch (err) {
        console.error('获取交易回执失败:', err);
        throw err;
      }
    }

    if (!receipt) {
      throw new Error('交易确认超时');
    }
    
    console.log(`交易已确认: ${txHash}, 状态: ${receipt.status}`);
    return receipt;
  };

  // 执行存款
  const handleDeposit = async () => {
    if (!account || !depositAmount) return

    try {
      setLoading(true)
      setError('')
      setTxHash('')
      
      // 将存款金额转换为Wei
      const amountInWei = parseEther(depositAmount);
      const amountHex = amountInWei.toString(16).padStart(64, '0');
      
      // 先授权TokenBank使用代币
      console.log('正在批准授权...');
      
      // approve(address,uint256) 函数的数据
      const approveData = `0x095ea7b3000000000000000000000000${formattedTokenBankAddress.slice(2)}${amountHex}`;
      
      const approveTx = await window.ethereum.request({
        method: 'eth_sendTransaction',
        params: [
          {
            from: account,
            to: tokenAddress,
            data: approveData,
          },
        ],
      });
      
      console.log('授权交易发送成功:', approveTx);
      setTxHash(approveTx);
      
      // 等待授权交易确认
      const approveReceipt = await waitForTransactionReceipt(approveTx);
      
      if (approveReceipt && approveReceipt.status === '0x1') {
        console.log('授权成功，正在存款...');
        
        // deposit(uint256) 函数的数据
        const depositData = `0xb6b55f25${amountHex}`;
        
        const depositTx = await window.ethereum.request({
          method: 'eth_sendTransaction',
          params: [
            {
              from: account,
              to: formattedTokenBankAddress,
              data: depositData,
            },
          ],
        });
        
        console.log('存款交易发送成功:', depositTx);
        setTxHash(depositTx);
        
        // 等待存款交易确认
        const depositReceipt = await waitForTransactionReceipt(depositTx);
        
        if (depositReceipt && depositReceipt.status === '0x1') {
          console.log('存款成功!');
          
          // 刷新余额
          await refreshBalances();
          
          // 清空输入框
          setDepositAmount('');
        } else {
          setError('存款交易失败，请检查交易详情');
        }
      } else {
        setError('授权交易失败，请检查交易详情');
      }
    } catch (err) {
      console.error('存款失败:', err);
      setError('存款失败: ' + (err.message || err));
    } finally {
      setLoading(false);
    }
  }

  // 执行提款
  const handleWithdraw = async () => {
    if (!account) return

    try {
      setLoading(true)
      setError('')
      setTxHash('')

      console.log('正在提款...');
      console.log('使用账户:', account);
      console.log('TokenBank地址:', formattedTokenBankAddress);
      
      // withdraw() 函数的数据
      const withdrawData = '0x3ccfd60b';
      
      try {
        const withdrawTx = await window.ethereum.request({
          method: 'eth_sendTransaction',
          params: [
            {
              from: account,
              to: formattedTokenBankAddress,
              data: withdrawData,
              gas: '0x186A0', // 十六进制的100,000，提供足够的gas限制
            },
          ],
        });
        
        console.log('提款交易发送成功:', withdrawTx);
        setTxHash(withdrawTx);
        
        // 等待提款交易确认
        const withdrawReceipt = await waitForTransactionReceipt(withdrawTx);
        
        if (withdrawReceipt && withdrawReceipt.status === '0x1') {
          console.log('提款成功!');
          
          // 刷新余额
          await refreshBalances();
        } else {
          const errorMsg = withdrawReceipt ? '交易执行失败（可能是合约拒绝了交易）' : '未收到交易回执';
          console.error('提款失败:', errorMsg);
          setError('提款交易失败: ' + errorMsg);
        }
      } catch (txError) {
        console.error('发送提款交易失败:', txError);
        setError('发送提款交易失败: ' + (txError.message || txError));
        
        // 尝试获取更详细的错误原因
        if (txError.code === 4001) {
          setError('您拒绝了交易');
        } else if (txError.code === -32603) {
          setError('内部错误: 可能是gas不足或合约执行失败');
        }
      }
    } catch (err) {
      console.error('提款操作失败:', err);
      setError('提款操作失败: ' + (err.message || err));
    } finally {
      setLoading(false);
    }
  }

  // 地址格式化
  const formatAddress = (address) => {
    if (!address) return ''
    return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`
  }

  // 交易哈希格式化并生成链接
  const formatTxLink = (hash) => {
    if (!hash) return null;
    const shortHash = `${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}`;
    const url = `https://sepolia.etherscan.io/tx/${hash}`;
    return (
      <a href={url} target="_blank" rel="noopener noreferrer">
        {shortHash}
      </a>
    );
  };

  return (
    <div className="container">
      <h1>Token Bank</h1>
      
      {!account ? (
        <div className="card">
          <p>请连接钱包以继续</p>
          {error && <p style={{ color: 'red' }}>{error}</p>}
        </div>
      ) : (
        <>
          <div className="card">
            <h2>账户信息</h2>
            <p>钱包地址: {formatAddress(account)}</p>
            <div className="balance-display">
              <p>代币余额: {parseFloat(tokenBalance).toFixed(4)} {tokenSymbol}</p>
              <p>存款余额: {parseFloat(bankBalance).toFixed(4)} {tokenSymbol}</p>
            </div>
            <button onClick={refreshBalances} disabled={loading}>
              刷新余额
            </button>
          </div>

          <div className="card">
            <h2>存款</h2>
            <div className="input-group">
              <input
                type="number"
                placeholder="输入存款金额"
                value={depositAmount}
                onChange={(e) => setDepositAmount(e.target.value)}
                disabled={loading}
              />
              <button onClick={handleDeposit} disabled={loading || !depositAmount}>
                {loading ? '处理中...' : '存款'}
              </button>
            </div>
          </div>

          <div className="card">
            <h2>提款</h2>
            <button 
              onClick={handleWithdraw} 
              disabled={loading || parseFloat(bankBalance) <= 0}
            >
              {loading ? '处理中...' : '提取全部'}
            </button>
            <p className="balance-display">
              将提取: {parseFloat(bankBalance).toFixed(4)} {tokenSymbol}
            </p>
          </div>

          {txHash && (
            <div className="card">
              <h3>最近交易</h3>
              <p>交易哈希: {formatTxLink(txHash)}</p>
            </div>
          )}

          {error && (
            <div className="card" style={{ backgroundColor: 'rgba(255, 0, 0, 0.1)' }}>
              <p style={{ color: 'red' }}>{error}</p>
            </div>
          )}
        </>
      )}
    </div>
  )
}

export default App 