'use client';

import { useAccount, useConnect, useDisconnect, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { NFT_MARKET_ADDRESS, NFT_MARKET_ABI } from '../config';
import { useState } from 'react';

export default function Home() {
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const [tokenId, setTokenId] = useState('');
  const [price, setPrice] = useState('');

  const { data: isListed } = useReadContract({
    address: NFT_MARKET_ADDRESS,
    abi: NFT_MARKET_ABI,
    functionName: 'isListed',
    args: [BigInt(tokenId || '0')],
    query: {
      enabled: !!tokenId,
    },
  });

  const { data: nftPrice } = useReadContract({
    address: NFT_MARKET_ADDRESS,
    abi: NFT_MARKET_ABI,
    functionName: 'getPrice',
    args: [BigInt(tokenId || '0')],
    query: {
      enabled: !!tokenId,
    },
  });

  const { writeContract: listNFT, data: listHash } = useWriteContract();

  const { writeContract: buyNFT, data: buyHash } = useWriteContract();

  const { isLoading: isListing } = useWaitForTransactionReceipt({
    hash: listHash,
  });

  const { isLoading: isBuying } = useWaitForTransactionReceipt({
    hash: buyHash,
  });

  const handleList = () => {
    if (!tokenId || !price) return;
    listNFT({
      address: NFT_MARKET_ADDRESS,
      abi: NFT_MARKET_ABI,
      functionName: 'listNFT',
      args: [BigInt(tokenId), BigInt(price)],
    });
  };

  const handleBuy = () => {
    if (!tokenId) return;
    buyNFT({
      address: NFT_MARKET_ADDRESS,
      abi: NFT_MARKET_ABI,
      functionName: 'buyNFT',
      args: [BigInt(tokenId)],
    });
  };

  return (
    <main className="min-h-screen p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-4xl font-bold mb-8">NFT 市场</h1>
        
        {!isConnected ? (
          <div className="mb-8 space-y-4">
            <h2 className="text-xl font-semibold">连接钱包</h2>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              {connectors.map((connector) => (
                <button
                  key={connector.uid}
                  onClick={() => connect({ connector })}
                  className="flex items-center justify-center px-4 py-2 text-white bg-blue-500 rounded hover:bg-blue-600"
                >
                  {connector.name}
                </button>
              ))}
            </div>
          </div>
        ) : (
          <div className="space-y-8">
            <div className="p-4 mb-8 text-white bg-green-500 rounded flex justify-between items-center">
              <span>已连接钱包: {String(address)}</span>
              <button
                onClick={() => disconnect()}
                className="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
              >
                断开连接
              </button>
            </div>
            <div className="bg-white p-6 rounded-lg shadow-md">
              <h2 className="text-2xl font-semibold mb-4">上架 NFT</h2>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Token ID</label>
                  <input
                    type="number"
                    value={tokenId}
                    onChange={(e) => setTokenId(e.target.value)}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">价格</label>
                  <input
                    type="number"
                    value={price}
                    onChange={(e) => setPrice(e.target.value)}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  />
                </div>
                <button
                  onClick={handleList}
                  disabled={isListing}
                  className="w-full bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600 disabled:opacity-50"
                >
                  {isListing ? '上架中...' : '上架 NFT'}
                </button>
              </div>
            </div>

            <div className="bg-white p-6 rounded-lg shadow-md">
              <h2 className="text-2xl font-semibold mb-4">NFT 信息</h2>
              {tokenId && (
                <div className="space-y-4">
                  <p>Token ID: {tokenId}</p>
                  <p>是否上架: {isListed ? '是' : '否'}</p>
                  {Boolean(isListed) && nftPrice && (
                    <p>价格: {nftPrice.toString()} wei</p>
                  )}
                  {Boolean(isListed) && (
                    <button
                      onClick={handleBuy}
                      disabled={isBuying}
                      className="w-full bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 disabled:opacity-50"
                    >
                      {isBuying ? '购买中...' : '购买 NFT'}
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </main>
  );
}
