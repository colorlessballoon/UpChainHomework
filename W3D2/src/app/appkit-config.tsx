import { createAppKit } from '@reown/appkit/react'
import { WagmiProvider } from 'wagmi'
import { sepolia } from '@reown/appkit/networks'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import type { AppKitNetwork } from '@reown/appkit/networks'

// 0. Setup queryClient
const queryClient = new QueryClient()

// 1. Get projectId from https://cloud.reown.com
const projectId = '6706c54c94f130118a3dfdfdbf3e313e'

// 2. 元数据在在钱包连接界面中显示 - Wallet Connect 扫码时将看到此信息
const metadata = {
  name: 'upchaintest',
  description: 'AppKit Example',
  url: 'https://reown.com/appkit',
  icons: ['https://learnblockchain.cn/image/avatar/412_big.jpg']
}

// 3. Set the networks
const networks: [AppKitNetwork, ...AppKitNetwork[]] = [sepolia];

// 4. Create Wagmi Adapter
const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId
});

// 5. 钱包连接模态框， 在调用 useAppKit 的 open 函数时显示
createAppKit({
  adapters: [wagmiAdapter],
  networks,
  projectId,
  metadata
})

export function AppKitProvider({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={wagmiAdapter.wagmiConfig}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  )
} 