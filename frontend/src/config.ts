import JankenABI from './abis/Janken.json'
import WramblingABI from './abis/Wrambling.json'
import { Address } from 'viem'

// Replace with actual deployed addresses
export const JANKEN_ADDRESS: Address = '0x986909a00B9377210443360e2DFF51c8483452E5'
export const WRAMBLING_ADDRESS: Address = '0xdB90ef07AC4Defad4C910317e1e0D5616dC43D3C'
export const CHAIN_ID = 763373 // Kraken Ink testnet

export const jankenAbi = JankenABI.abi
export const wramblingAbi = WramblingABI.abi
