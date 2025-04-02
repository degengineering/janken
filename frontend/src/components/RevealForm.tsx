'use client'
import { useState } from 'react'
import { useWriteContract } from 'wagmi'
import { jankenAbi, JANKEN_ADDRESS } from '../config'
import { parseEther } from 'viem'

export default function RevealForm() {
  const [challenged, setChallenged] = useState('')
  const [secret, setSecret] = useState('')
  const [move, setMove] = useState(0)

  const { writeContractAsync } = useWriteContract()

  const reveal = async () => {
    await writeContractAsync({
      address: JANKEN_ADDRESS,
      abi: jankenAbi,
      functionName: 'reveal',
      args: [challenged, secret, move, false],
      value: parseEther('0.001'),
    })
  }

  return (
    <div>
      <h3>Reveal Your Move</h3>
      <input
        placeholder="Challenged address"
        value={challenged}
        onChange={(e) => setChallenged(e.target.value)}
      />
      <select onChange={(e) => setMove(parseInt(e.target.value))}>
        <option value="0">Rock</option>
        <option value="1">Paper</option>
        <option value="2">Scissors</option>
      </select>
      <input
        placeholder="Secret"
        value={secret}
        onChange={(e) => setSecret(e.target.value)}
      />
      <button onClick={reveal}>Reveal</button>
    </div>
  )
}
