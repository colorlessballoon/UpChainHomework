'use client';

import { useState, useEffect } from 'react';
import {
    useAccount,
    useDisconnect,
    useChainId,
    useChains,
    useWriteContract,
    useBalance
} from 'wagmi';
import { AppKitProvider } from './appkit-config';
import { useAppKit } from '@reown/appkit/react';
import NFTMarket_ABI from '@/contracts/NFTMarket.json';

// NFTMarket 合约地址
const NFT_MARKET_ADDRESS = "0x382f35593f84404e908d474da496e0954101fae7";
// NFT 合约地址
const NFT_CONTRACT_ADDRESS = "0x5a0ab1e35734708996b2187c3b90930be3a756ba";

function AppkitDemoContent() {
    const { address, isConnected } = useAccount();
    const { open } = useAppKit();
    const { disconnect } = useDisconnect();
    const { writeContract, isPending, isSuccess, isError, error } = useWriteContract();
    const chainId = useChainId();
    const chains = useChains();
    const currentChain = chains.find(chain => chain.id === chainId);

    // 上架表单状态
    const [tokenId, setTokenId] = useState<string>('');
    const [price, setPrice] = useState<string>('');
    const [formError, setFormError] = useState<string>('');

    // 购买表单状态
    const [buyTokenId, setBuyTokenId] = useState<string>('');
    const [buyFormError, setBuyFormError] = useState<string>('');

    // 获取当前账户的余额信息
    const { data: balance } = useBalance({
        address,
    });

    // 处理 NFT 上架
    const handleListNFT = () => {
        // 表单验证
        if (!tokenId || !price) {
            setFormError('请填写完整的 NFT 信息');
            return;
        }

        const tokenIdNum = parseInt(tokenId);
        if (isNaN(tokenIdNum) || tokenIdNum < 0) {
            setFormError('Token ID 必须是有效的数字');
            return;
        }

        const priceNum = parseFloat(price);
        if (isNaN(priceNum) || priceNum <= 0) {
            setFormError('价格必须是大于 0 的数字');
            return;
        }

        // 清除之前的错误
        setFormError('');

        // 将 ETH 价格转换为 wei
        const priceInWei = BigInt(Math.floor(priceNum * 1e18));

        writeContract({
            address: NFT_MARKET_ADDRESS as `0x${string}`,
            abi: NFTMarket_ABI,
            functionName: 'list',
            args: [
                NFT_CONTRACT_ADDRESS,
                tokenIdNum,
                priceInWei
            ],
        });
    };

    // 处理 NFT 购买
    const handleBuyNFT = () => {
        // 表单验证
        if (!buyTokenId) {
            setBuyFormError('请输入要购买的 NFT Token ID');
            return;
        }

        const tokenIdNum = parseInt(buyTokenId);
        if (isNaN(tokenIdNum) || tokenIdNum < 0) {
            setBuyFormError('Token ID 必须是有效的数字');
            return;
        }

        // 清除之前的错误
        setBuyFormError('');

        writeContract({
            address: NFT_MARKET_ADDRESS as `0x${string}`,
            abi: NFTMarket_ABI,
            functionName: 'buy',
            args: [
                NFT_CONTRACT_ADDRESS,
                tokenIdNum
            ],
        });
    };

    // 监听交易成功
    useEffect(() => {
        if (isSuccess) {
            // 清空表单
            setTokenId('');
            setPrice('');
            setFormError('');
            setBuyTokenId('');
            setBuyFormError('');
        }
    }, [isSuccess]);

    return (
        <div className="min-h-screen flex flex-col items-center justify-center p-8">
            <h1 className="text-3xl font-bold mb-8">NFTMarket List Function</h1>

            <div className="bg-white p-6 rounded-lg shadow-lg w-full max-w-2xl">
                {/* 根据钱包连接状态显示不同的内容 */}
                {!isConnected ? (
                    // 未连接钱包时显示连接按钮
                    <button
                        onClick={() => open()}
                        className="w-full bg-blue-500 text-white py-2 px-4 rounded hover:bg-blue-600 transition-colors"
                    >
                        连接钱包
                    </button>
                ) : (
                    // 已连接钱包时显示详细信息
                    <div className="space-y-8">
                        {/* 显示钱包地址 */}
                        <div className="text-center">
                            <p className="text-gray-600">钱包地址:</p>
                            <p className="font-mono break-all">{address}</p>
                        </div>
                        {/* 显示当前网络信息 */}
                        <div className="text-center">
                            <p className="text-gray-600">当前网络:</p>
                            <p className="font-mono">
                                {currentChain?.name || '未知网络'} (Chain ID: {chainId})
                            </p>
                            {/* 切换网络的按钮 */}
                            <button 
                                onClick={() => open({ view: 'Networks' })}
                                className="mt-2 bg-purple-500 text-white py-1 px-3 rounded hover:bg-purple-600 transition-colors"
                            >
                                切换网络
                            </button>
                        </div>
                        {/* 显示账户余额 */}
                        <div className="text-center">
                            <p className="text-gray-600">余额:</p>
                            <p className="font-mono">
                                {balance?.formatted || '0'} {balance?.symbol}
                            </p>
                        </div>

                        {/* NFT 上架表单 */}
                        <div className="text-center space-y-4 border-t pt-4">
                            <h2 className="text-xl font-semibold">上架 NFT</h2>
                            <div>
                                <label className="block text-gray-600 mb-2">Token ID:</label>
                                <input
                                    type="number"
                                    value={tokenId}
                                    onChange={(e) => setTokenId(e.target.value)}
                                    className="w-full p-2 border rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                                    placeholder="输入 NFT Token ID"
                                    disabled={isPending}
                                />
                            </div>
                            <div>
                                <label className="block text-gray-600 mb-2">价格 (ETH):</label>
                                <input
                                    type="number"
                                    value={price}
                                    onChange={(e) => setPrice(e.target.value)}
                                    className="w-full p-2 border rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                                    placeholder="输入 NFT 价格"
                                    step="0.000000000000000001"
                                    disabled={isPending}
                                />
                            </div>
                            {formError && (
                                <p className="text-red-500">{formError}</p>
                            )}
                            <button
                                onClick={handleListNFT}
                                disabled={isPending}
                                className={`w-full py-2 px-4 rounded transition-colors ${
                                    isPending
                                        ? 'bg-gray-400 cursor-not-allowed'
                                        : 'bg-green-500 hover:bg-green-600 text-white'
                                }`}
                            >
                                {isPending ? '处理中...' : '上架 NFT'}
                            </button>
                        </div>

                        {/* NFT 购买表单 */}
                        <div className="text-center space-y-4 border-t pt-4">
                            <h2 className="text-xl font-semibold">购买 NFT</h2>
                            <div>
                                <label className="block text-gray-600 mb-2">Token ID:</label>
                                <input
                                    type="number"
                                    value={buyTokenId}
                                    onChange={(e) => setBuyTokenId(e.target.value)}
                                    className="w-full p-2 border rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                                    placeholder="输入要购买的 NFT Token ID"
                                    disabled={isPending}
                                />
                            </div>
                            {buyFormError && (
                                <p className="text-red-500">{buyFormError}</p>
                            )}
                            <button
                                onClick={handleBuyNFT}
                                disabled={isPending}
                                className={`w-full py-2 px-4 rounded transition-colors ${
                                    isPending
                                        ? 'bg-gray-400 cursor-not-allowed'
                                        : 'bg-blue-500 hover:bg-blue-600 text-white'
                                }`}
                            >
                                {isPending ? '处理中...' : '购买 NFT'}
                            </button>
                        </div>

                        {/* 交易状态显示 */}
                        <div className="text-center border-t pt-4">
                            {isPending && (
                                <p className="text-gray-600">交易正在处理中...</p>
                            )}
                            {isError && (
                                <p className="text-red-500">
                                    错误: {error?.message}
                                </p>
                            )}
                            {isSuccess && (
                                <p className="text-green-500">
                                    交易成功！
                                </p>
                            )}
                        </div>

                        {/* 断开连接按钮 */}
                        <button
                            onClick={() => disconnect()}
                            className="w-full bg-red-500 text-white py-2 px-4 rounded hover:bg-red-600 transition-colors"
                        >
                            断开连接
                        </button>
                    </div>
                )}
            </div>
        </div>
    );
}

export default function AppkitDemo() {
    return (
        <AppKitProvider>
            <AppkitDemoContent />
        </AppKitProvider>
    );
} 