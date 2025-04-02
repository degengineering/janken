'use client'
import { useAccount, useConnect, useDisconnect } from 'wagmi'

export default function ConnectWallet() {
  const { status, addresses, chainId } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()

  if (status === 'connected') {
    return (
      <div>
        Connected as: {addresses[0]} <br />
        Chain: {chainId}
        <button onClick={() => disconnect()}>Disconnect</button>
      </div>
    )
  }

  return (
    <div>
      {connectors.map((connector) => (
        <button key={connector.uid} onClick={() => connect({ connector })}>
          Connect with {connector.name}
        </button>
      ))}
    </div>
  )
}
