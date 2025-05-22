import { http } from 'viem';
import { createConfig } from 'wagmi';
import { sepolia } from 'wagmi/chains';
import { injected, metaMask, walletConnect } from 'wagmi/connectors';

export const config = createConfig({
  chains: [sepolia],
  connectors: [
    injected(),
    metaMask(),
    walletConnect({
      projectId: 'YOUR_PROJECT_ID', // 这里需要替换为您的 WalletConnect Project ID
    }),
  ],
  transports: {
    [sepolia.id]: http('https://rpc.sepolia.org'),
  },
}); 