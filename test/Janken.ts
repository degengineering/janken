import hre from "hardhat";
import { assert, expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { AbiParameter, encodePacked, keccak256, parseEther } from "viem";

import erc20Json from "@openzeppelin/contracts/build/contracts/ERC20.json";

import JankenArtifact from "../artifacts/contracts/Janken.sol/Janken.json";
import ERC20Artifact from "@openzeppelin/contracts/build/contracts/ERC20.json";

// Requested fee
const fee = parseEther("0.001");

// Types
type Move = 0 | 1 | 2; // Rock, Paper, Scissors

// A deployment function to set up the initial state
const deployJanken = async () => {
  const janken = await hre.viem.deployContract("Janken", [fee]);

  return { janken };
};

const deployERC20 = async () => {
  const erc20 = await hre.viem.deployContract("TestToken", ["Test Token", "TTK"]);

  return { erc20 };
}

// Utils
const buildCommitment = (move: Move, secret: string): `0x${string}` => {
  const types: readonly AbiParameter[] = [
    { type: "uint8", name: "move" },
    { type: "string", name: "secret" }
  ];
  const values: [Move, string] = [move, secret];
  const encoded = encodePacked(['uint8', 'string'], values);
  return keccak256(encoded);
};

describe("Janken", () => {

  it("should allow a complete game with draw", async () => {

    const { janken } = await loadFixture(deployJanken);
    const { erc20 } = await loadFixture(deployERC20);
    const [walletClientChallenger, walletClientChallenged] = await hre.viem.getWalletClients();
    const m1 = erc20.write.mint([walletClientChallenger.account.address, 100000n]);
    const m2 = erc20.write.mint([walletClientChallenged.account.address, 100000n]);
    await Promise.all([m1, m2]);
    const challengerInitBalance = await erc20.read.balanceOf([walletClientChallenger.account.address]);
    const challengedInitBalance = await erc20.read.balanceOf([walletClientChallenged.account.address]);
    
    console.log("Challenger balance: ", challengerInitBalance);
    console.log("Challenged balance: ", challengedInitBalance);
    // SHow the addresses of challenger and challenged and contracts
    console.log("Challenger address: ", walletClientChallenger.account.address);
    console.log("Challenged address: ", walletClientChallenged.account.address);
    console.log("Janken address: ", janken.address);
    console.log("ERC20 address: ", erc20.address);

    // Challenger starts the game by committing to a move
    const move: Move = 0; // Rock
    const secret = "verySecret123";
    const commitment = buildCommitment(move, secret);
    const pledgeAmount = 100n;

    // Verify that the commitment is correct
    const r = await janken.read.verifyCommitment([commitment, secret, move])
    expect(r).to.equal(true);

    await erc20.write.approve([janken.address, pledgeAmount], {account: walletClientChallenger.account});
    await janken.write.challenge([walletClientChallenged.account.address, commitment, erc20.address, pledgeAmount], {
      account: walletClientChallenger.account,
      value: fee
    });

    // Challenged plays the challenger's game with same move (Rock) to force draw
    await erc20.write.approve([janken.address, pledgeAmount], {account: walletClientChallenged.account});
    await janken.write.play([walletClientChallenger.account.address, move, erc20.address, pledgeAmount, false], {
      account: walletClientChallenged.account,
      value: fee
    });

    // Switch back to challenger
    await janken.write.reveal([walletClientChallenged.account.address, secret, move, false], {
      account: walletClientChallenger.account,
      value: fee
    });

    // Check stats
    const challengerStats = await janken.read.playerStats([walletClientChallenger.account.address]);
    const challengedStats = await janken.read.playerStats([walletClientChallenged.account.address]);

    expect(challengerStats[2]).equal(1n);
    expect(challengedStats[2]).equal(1n);

    // Check balances
    expect(await erc20.read.balanceOf([walletClientChallenger.account.address])).equal(challengerInitBalance);
    expect(await erc20.read.balanceOf([walletClientChallenged.account.address])).equal(challengedInitBalance);
  });

  it("should allow challenger to win with Rock vs Scissors", async () => {

    const { janken } = await loadFixture(deployJanken);
    const { erc20 } = await loadFixture(deployERC20);
    const [walletClientChallenger, walletClientChallenged] = await hre.viem.getWalletClients();
    const m1 = erc20.write.mint([walletClientChallenger.account.address, 100000n]);
    const m2 = erc20.write.mint([walletClientChallenged.account.address, 100000n]);
    await Promise.all([m1, m2]);
    const challengerInitBalance = await erc20.read.balanceOf([walletClientChallenger.account.address]);
    const challengedInitBalance = await erc20.read.balanceOf([walletClientChallenged.account.address]);

    const move: Move = 0; // Rock
    const secret = "verySecret123";
    const commitment = buildCommitment(move, secret);
    const pledgeAmount = 100n;

    // Challenger starts the game by committing to a move
    await erc20.write.approve([janken.address, pledgeAmount], {account: walletClientChallenger.account});
    await janken.write.challenge([walletClientChallenged.account.address, commitment, erc20.address, pledgeAmount], {
      account: walletClientChallenger.account,
      value: fee
    });
  
    // Challenged plays Scissors (2)
    await erc20.write.approve([janken.address, pledgeAmount], {account: walletClientChallenged.account});
    await janken.write.play([walletClientChallenger.account.address, 2, erc20.address, pledgeAmount, false], {
      account: walletClientChallenged.account,
      value: fee
    });

    // Reveal: Rock vs Scissors → Challenger wins
    await janken.write.reveal([walletClientChallenged.account.address, secret, move, false], {
      account: walletClientChallenger.account,
      value: fee
    });

    // Check stats
    const challengerStats = await janken.read.playerStats([walletClientChallenger.account.address]);
    const challengedStats = await janken.read.playerStats([walletClientChallenged.account.address]);
    expect(challengerStats[0]).equal(1n);
    expect(challengedStats[1]).equal(1n);

    // Check balances
    expect(await erc20.read.balanceOf([walletClientChallenger.account.address])).equal(challengerInitBalance + pledgeAmount);
    expect(await erc20.read.balanceOf([walletClientChallenged.account.address])).equal(challengedInitBalance - pledgeAmount);
  });
  
  it("should allow challenged player to win with Papper vs Rock", async () => {

    const { janken } = await loadFixture(deployJanken);
    const { erc20 } = await loadFixture(deployERC20);
    const [walletClientChallenger, walletClientChallenged] = await hre.viem.getWalletClients();
    const m1 = erc20.write.mint([walletClientChallenger.account.address, 100000n]);
    const m2 = erc20.write.mint([walletClientChallenged.account.address, 100000n]);
    await Promise.all([m1, m2]);
    const challengerInitBalance = await erc20.read.balanceOf([walletClientChallenger.account.address]);
    const challengedInitBalance = await erc20.read.balanceOf([walletClientChallenged.account.address]);

    const move: Move = 0; // Rock
    const secret = "verySecret123";
    const commitment = buildCommitment(move, secret);
    const pledgeAmount = 100n;

    // Challenger starts the game by committing to a move
    await erc20.write.approve([janken.address, pledgeAmount], {account: walletClientChallenger.account});
    await janken.write.challenge([walletClientChallenged.account.address, commitment, erc20.address, pledgeAmount], {
      account: walletClientChallenger.account,
      value: fee
    });
  
    // Challenged plays Papper (1)
    await erc20.write.approve([janken.address, pledgeAmount], {account: walletClientChallenged.account});
    await janken.write.play([walletClientChallenger.account.address, 1, erc20.address, pledgeAmount, false], {
      account: walletClientChallenged.account,
      value: fee
    });

    // Reveal: Papper vs Rock → Challenged player wins
    await janken.write.reveal([walletClientChallenged.account.address, secret, move, false], {
      account: walletClientChallenger.account,
      value: fee
    });

    // Check stats
    const challengerStats = await janken.read.playerStats([walletClientChallenger.account.address]);
    const challengedStats = await janken.read.playerStats([walletClientChallenged.account.address]);
    expect(challengerStats[1]).equal(1n);
    expect(challengedStats[0]).equal(1n);

    // Check balances
    expect(await erc20.read.balanceOf([walletClientChallenger.account.address])).equal(challengerInitBalance - pledgeAmount);
    expect(await erc20.read.balanceOf([walletClientChallenged.account.address])).equal(challengedInitBalance + pledgeAmount);
  });

  it("should allow chicken out if reveal deadline missed", async () => {

    const { janken } = await loadFixture(deployJanken);
    const { erc20 } = await loadFixture(deployERC20);
    const [walletClientChallenger, walletClientChallenged] = await hre.viem.getWalletClients();
    const m1 = erc20.write.mint([walletClientChallenger.account.address, 100000n]);
    const m2 = erc20.write.mint([walletClientChallenged.account.address, 100000n]);
    await Promise.all([m1, m2]);
    const challengerInitBalance = await erc20.read.balanceOf([walletClientChallenger.account.address]);
    const challengedInitBalance = await erc20.read.balanceOf([walletClientChallenged.account.address]);

    const secret = "timeout";
    const commitment = buildCommitment(1, secret); // Paper
    const pledgeAmount = 100n;

    await erc20.write.approve([janken.address, pledgeAmount], {account: walletClientChallenger.account});
    await janken.write.challenge([walletClientChallenged.account.address, commitment, erc20.address, pledgeAmount], {
      account: walletClientChallenger.account,
      value: fee
    });

    await erc20.write.approve([janken.address, pledgeAmount], {account: walletClientChallenged.account});
    await janken.write.play([walletClientChallenger.account.address, 2, erc20.address, pledgeAmount, false], {
      account: walletClientChallenged.account,
      value: fee
    });

    // Manually advance time (Hardhat only)
    await hre.network.provider.send("evm_increaseTime", [8 * 24 * 60 * 60 + 1]); // +8 days
    await hre.network.provider.send("evm_mine");

    // Challenger should be able to call challenger chicken
    await janken.write.callChallengerChicken([walletClientChallenger.account.address, false], {
      account: walletClientChallenged.account,
      value: fee
    });

    // Check stats
    const challengerStats: any = await janken.read.playerStats([walletClientChallenger.account.address]);
    expect(challengerStats[3]).equal(1n);

    // Check balances
    expect(await erc20.read.balanceOf([walletClientChallenger.account.address])).equal(challengerInitBalance - pledgeAmount);
    expect(await erc20.read.balanceOf([walletClientChallenged.account.address])).equal(challengedInitBalance + pledgeAmount);
  });
});
