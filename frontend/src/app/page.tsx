'use client'

import ConnectWallet from '../components/ConnectWallet'
import ChallengeForm from '../components/ChallengeForm'
import RevealForm from '../components/RevealForm'
import NetworkGuard from '../components/NetworkGuard'

export default function Page() {
  return (
    <main style={{ padding: 20 }}>
      <NetworkGuard>
        <h1>🪨📜✂️ On-Chain Janken</h1>
        <ConnectWallet />
        <hr />
        <ChallengeForm />
        <RevealForm />
      </NetworkGuard>
    </main>
  )
}
