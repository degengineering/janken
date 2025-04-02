'use client'
import { useState } from 'react'
import { useWriteContract } from 'wagmi'
import { jankenAbi, JANKEN_ADDRESS, WRAMBLING_ADDRESS } from '../config'
import { keccak256, encodePacked, parseEther } from 'viem'

export default function ChallengeForm() {
  const [challenged, setChallenged] = useState('')
  const [move, setMove] = useState(0)
  const [secret, setSecret] = useState('')
  const [pledge, setPledge] = useState('')

  const { writeContractAsync } = useWriteContract()

  const submit = async () => {
    const commitment = keccak256(
      encodePacked(['uint8', 'string'], [move, secret])
    )

    await writeContractAsync({
      address: JANKEN_ADDRESS,
      abi: jankenAbi,
      functionName: 'challenge',
      args: [challenged, commitment, WRAMBLING_ADDRESS, BigInt(pledge)],
      value: parseEther('0.001'),
    })
  }

  return (
    <div>
      <h3>Challenge Someone</h3>
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
      <input
        placeholder="Pledge amount"
        value={pledge}
        onChange={(e) => setPledge(e.target.value)}
      />
      <button onClick={submit}>Commit Move</button>
    </div>
  )
}
