# 🪨📄✂️ Janken On-Chain — Rock, Paper, Scissors with Tokens & Glory

Welcome to **Janken**, a fully on-chain, gas-conscious, and meme-powered implementation of Rock, Paper, Scissors — built for players, powered by smart contracts, and extendable by developers.

Battle your friends, pledge your favorite ERC20 meme coins, and track your stats. No take-backs. No excuses. If you chicken out… the blockchain remembers 👀

---

## 🧭 Overview

- ⚔️ **Challenge Friends** in commit-reveal Rock, Paper, Scissors
- 🐔 **7-Day Timeout Rule** — Players have **7 days** to reply to a challenge or to reveal their move. If not, they’ll be called *chicken* by the opponent and forfeit the match. 
- 💰 **Stake ERC20 Tokens** as a wager (meme coins welcome!)
- 🧾 **Pay Small Fees** on top of gas to support the game
- 🧠 **Track Your Stats** (wins, losses, draws, and chicken outs)
- 🧱 **Built on Solidity** using OpenZeppelin security patterns

---

## 🧑‍💻 Developers

Want to integrate Janken into your dApp, tweak it, or build your own layer on top? Start here 👇

### 🔨 Features

- Built in Solidity ^0.8.24
- Modular fee system (`Fees.sol`)
- ERC20 staking logic with safe transfer handling
- Commit-reveal move validation using `keccak256`
- OpenZeppelin `Ownable` for permissioned control

### 📦 Contracts

- `Janken.sol` — Main game logic
- `Fees.sol` — Owner-controlled service fee system

### 📁 Local Dev Setup

```bash
git clone https://github.com/your-org/janken.git
cd janken
npm install
npx hardhat compile
