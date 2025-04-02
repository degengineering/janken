'use client'

import { useChainId, useSwitchChain } from 'wagmi'
import { inkSepolia } from 'wagmi/chains'

export default function NetworkGuard({ children }: { children: React.ReactNode }) {
  const chainId = useChainId()
  const { switchChain } = useSwitchChain()

  const isWrongChain = chainId !== inkSepolia.id

  if (isWrongChain) {
    return (
      <div className="p-4 text-red-600 text-center">
        <p>⚠️ Please switch to Kraken Ink Sepolia Testnet.</p>
        <button
          className="mt-2 bg-blue-500 text-white px-4 py-2 rounded"
          onClick={() => switchChain({ chainId: inkSepolia.id })}
        >
          Switch to Ink Sepolia
        </button>
      </div>
    )
  }

  return <>{children}</>
}
