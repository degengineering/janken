// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Fees.sol";

/**
 * @title Janken
 * 
 * @author degengineering.ink
 * 
 * @notice A simple implementation of the Janken game (Rock, Paper, Scissors) on Ethereum. Come and play with your friends! Pledge your finest meme coins! 
 * And if you chicken out, you will be called out!
 * 
 * @dev This contract allows two players to challenge each other to a game of Janken. Players can commit their moves and reveal them later.
 * The game has a commit-reveal phase, where players can commit their moves and then reveal them. The winner is determined based on the rules of Janken.
 * The contract also supports ERC20 token pledges, allowing players to stake tokens as part of the game. The contract keeps track of player statistics, including wins, losses, draws, and chicken outs.
 * Players can challenge each other, commit their moves, and reveal them. The game state is managed using an enum to track the current phase of the game.
 * The contract emits events for game start, player commitment, and game finish, allowing external applications to listen for these events.
 * The contract uses OpenZeppelin's Ownable and ERC20 interfaces for token transfers and ownership management. 
 */
contract Janken is Fees {

    event GameStarted(uint256 indexed gameId, address indexed challenger, address indexed challenged, uint256 commitDeadline, address challengerErc20Token, uint256 challengerErc20Pledge);
    event GameOn(uint256 indexed gameId, address indexed challenger, address indexed challenged, uint256 revealDeadline, address challengedErc20Token, uint256 challengedErc20Pledge);
    event GameFinished(uint256 indexed gameId, address indexed challenger, address indexed challenged, Result result);

    uint256 constant COMMIT_DURATION = 7 days;
    uint256 constant REVEAL_DURATION = 7 days;

    enum Move {
        Rock,
        Paper,
        Scissors
    }

    enum Result {
        ChallengerWin,
        ChallengedWin,
        Draw,
        ChallengerChickenOut,
        ChallengedChickenOut
    }

    enum GameState {
        CommitPhase,
        RevealPhase,
        Finished
    }

    struct Game {
        uint256 id;
        bytes32 commitment;
        GameState gameState;
        address challengerErc20Token;
        uint256 challengerErc20Pledge;
        address challengedErc20Token;
        uint256 challengedErc20Pledge;
        Move challengedMove;
        uint256 commitDeadline;
        uint256 revealDeadline;
    }

    struct PlayerStats {
        uint256 wins;
        uint256 losses;
        uint256 draws;
        uint256 chickenOuts;
    }

    mapping(address => mapping (address => Game)) public games;
    mapping(address => PlayerStats) public playerStats;
    uint256 public gameCounter;

    /**
     * @notice Constructor to initialize the contract with a service fee.
     * @param fee The service fee in wei.
     */
    constructor(uint256 fee) Fees(fee) {
        gameCounter = 0;
    }

    /**
     * @notice Start a new game by challenging another player and committing a move. Optionally, you can specify an ERC20 token and a pledge amount.
     * The pledge amount will be transferred to the contract and can be used as a stake in the game. Note: the challenged player does not need to
     * pledge anything back.
     * 
     * @dev The commitment is a hash of the move and a secret. The secret must be a strong, unique password to prevent brute-force attacks.
     * The commitment hash is keccak256(abi.encodePacked(_move, _secret)).
     * 
     * @param challengedPlayer The address of the player being challenged.
     * @param commitment The commitment hash of the move.
     */
    function challenge(address challengedPlayer, bytes32 commitment, address erc20, uint256 pledge) external payable collectFee {
        require(msg.sender != challengedPlayer, "Cannot challenge yourself");
        require(challengedPlayer != address(0), "Invalid challenged player");
        require(commitment != bytes32(0), "Commitment cannot be empty");
        require(games[msg.sender][challengedPlayer].commitment == bytes32(0), "Game already exists");
        require(games[challengedPlayer][msg.sender].commitment == bytes32(0), "Game already exists");

        // Create a new game
        Game storage newGame = games[msg.sender][challengedPlayer];
        newGame.id = gameCounter;
        newGame.commitment = commitment;
        newGame.gameState = GameState.CommitPhase;
        newGame.commitDeadline = block.timestamp + COMMIT_DURATION;
        gameCounter++;

        // In case the challenged player pledge some token, verify the smart contract has the approval to transfer the pledged amount
        if (pledge > 0) {
            require(erc20 != address(0), "Invalid ERC20 token address");
            newGame.challengerErc20Token = erc20;
            newGame.challengerErc20Pledge = pledge;
            require(IERC20(erc20).allowance(msg.sender, address(this)) == pledge, "Not enough allowance to the smart contract");
        }
        emit GameStarted(newGame.id, msg.sender, challengedPlayer, newGame.commitDeadline, erc20, pledge);
    }

    /**
     * @notice Call this function to chicken out the challenged player if they do not commit their move within the deadline.
     * The function returns true if the challenged player has chicken out and the game is finished. If false, the game is still ongoing.
     * 
     * @dev This function can only be called by the challenger. If the challenged player does not commit their move within the deadline,
     * the contract will automatically call chicken out and transfer the pledged ERC20 tokens back to the challenger if any.
     * 
     * @param challengedPlayer The address of the player being challenged.
     * @param keepIt If true, the contract keeps the pledged ERC20 tokens. This is useful in case the transfer fails to unstuck the game.
     */
    function callChallengedChicken(address challengedPlayer, bool keepIt) external payable collectFee nonReentrant returns (bool) {
        Game storage game = games[msg.sender][challengedPlayer];
        require(game.commitment != bytes32(0), "Game does not exist");
        require(game.gameState == GameState.CommitPhase, "Invalid game state");
        return _checkAndResolveChalengedChicken(game, msg.sender, challengedPlayer, keepIt);
    }

    /**
     * @dev Check if the challenged player has chicken out. If so, the game is finished and the pledged ERC20 tokens are transferred back to the challenger.
     * If the challenged player has not chicken out, the game is still ongoing and the function returns false.
     * 
     * @param game The game object.
     * @param challenger The address of the challenger.
     * @param challengedPlayer The address of the player being challenged.
     * @param keepIt Indicates if the pledged ERC20 tokens should be kept by the contract or transferred back to the challenger. This is useful in case the transfer fails to unstuck the game.
     */
    function _checkAndResolveChalengedChicken(Game storage game, address challenger, address challengedPlayer, bool keepIt) internal returns (bool) {
        // Check if the deadline has passed and call chicken out if so
        if (block.timestamp > game.commitDeadline) {
            _settle(game, challenger, challengedPlayer, Result.ChallengedChickenOut, keepIt);
            return true;
        }
        return false;
    }

    /**
     * @notice The challenged player can reply to the challenge and commit its move. Optionally, they can also specify an ERC20 token and a pledge amount.
     * The pledge amount will be transferred to the contract and can be used as a stake in the game. Note: the challenger does not need to
     * pledge anything back.
     * 
     * @dev Once the challenger has committed their move, the challenged player must reveal their move within the specified deadline or
     * be called out for chicken out. The reveal is done by the challenger calling the `reveal` function with the secret and the move.
     * 
     * @param challenger The address of the player who challenged the sender. 
     * @param move The move of the challenged player (Rock, Paper, or Scissors).
     * @param erc20 The address of the ERC20 token to be used as a pledge.
     * @param pledge The amount of the ERC20 token to be used as a pledge.
     * @param keepIt If true, the contract keeps the pledged ERC20 tokens. This is useful in case the transfer fails to unstuck the game.
     */
    function play(address challenger, Move move, address erc20, uint256 pledge, bool keepIt) external payable nonReentrant collectFee {
        Game storage game = games[challenger][msg.sender];
        require(game.commitment != bytes32(0), "Game does not exist");
        require(game.gameState == GameState.CommitPhase, "Invalid game state");

        // Check if the challenged player hasn't chicken out and resolve the game if so
        if (_checkAndResolveChalengedChicken(game, challenger, msg.sender, keepIt)) {
            return;
        }

        // Game on - Commit the move
        game.challengedMove = move;
        game.gameState = GameState.RevealPhase;
        game.revealDeadline = block.timestamp + REVEAL_DURATION;

        // In case the challenged player pledge some token, verify the smart contract has the approval to transfer the pledged amount
        if (pledge > 0) {
            require(erc20 != address(0), "Invalid ERC20 token address");
            game.challengedErc20Token = erc20;
            game.challengedErc20Pledge = pledge;
            require(IERC20(erc20).allowance(msg.sender, address(this)) == pledge, "Not enough allowance to the smart contract");
        }
        emit GameOn(game.id, challenger, msg.sender, game.revealDeadline, erc20, pledge);
    }

    /**
     * @notice Call this function to chicken out the challenger if they do not reveal their move within the deadline.
     * The function returns true if the challenger has chicken out and the game is finished. If false, the game is still ongoing.
     * 
     * @dev This function can only be called by the challenged player. If the challenger does not reveal their move within the deadline,
     * the contract will automatically call chicken out and transfer the pledged ERC20 tokens back to the challenged player if any.
     * 
     * @param challenger The address of the player who challenged the sender.
     * @param keepIt If true, the contract keeps the pledged ERC20 tokens. This is useful in case the transfer fails to unstuck the game.
     */
    function callChallengerChicken(address challenger, bool keepIt) external payable collectFee nonReentrant returns (bool) {
        Game storage game = games[challenger][msg.sender];
        require(game.commitment != bytes32(0), "Game does not exist");
        require(game.gameState == GameState.RevealPhase, "Invalid game state");
        return _checkAndResolveChallengerChicken(game, challenger, msg.sender, keepIt);
    }

    /**
     * @dev Check if the challenger has chicken out. If so, the game is finished and the pledged ERC20 tokens are transferred back to the challenged player.
     * If the challenger has not chicken out, the game is still ongoing and the function returns false.
     * 
     * @param challenger The address of the challenger.
     * @param challengedPlayer The address of the player being challenged.
     * @param keepIt Indicates if the pledged ERC20 tokens should be kept by the contract or transferred back to the challenger. This is useful in case the transfer fails to unstuck the game.
     */
    function _checkAndResolveChallengerChicken(Game storage game, address challenger, address challengedPlayer, bool keepIt) internal returns (bool) {
        // Check if the deadline has passed and call chicken out if so
        if (block.timestamp > game.revealDeadline) {
            _settle(game, challenger, challengedPlayer, Result.ChallengerChickenOut, keepIt);
            return true;
        }
        return false;
    }

    /**
     * @notice Reveal the move made by the challenger and settle the game.
     * 
     * @dev The secret and the move must match the commitment hash. A utility function named `verifyCommitment` is provided to help you with
     * testing the logic to craf the commitment hash. Providing a wrong secret or move or being behind the deadline will result in a loss for the challenger (no mercy!). 
     * The contract will automatically determine the winner based on the rules of Janken. The contract will also transfer the pledged ERC20 tokens to the winner.
     * 
     * @param challengedPlayer The address of the player being challenged.
     * @param secret The secret used to create the commitment hash.
     * @param move The move of the player used to create the commitment hash (Rock, Paper, or Scissors).
     */
    function reveal(address challengedPlayer, string calldata secret, Move move, bool keepIt) external payable collectFee nonReentrant{
        Game storage game = games[msg.sender][challengedPlayer];
        require(game.commitment != bytes32(0), "Game does not exist");
        require(game.gameState == GameState.RevealPhase, "Invalid game state");

        // Check if the reveal deadline has passed. In that case, the challenger is called out for chicken out.
        if (_checkAndResolveChallengerChicken(game, msg.sender, challengedPlayer, keepIt)) {
            return;
        }

        // Verify the commitment. If not valid, the challenger is called out for chicken.
        if (!_verifyCommitment(game.commitment, secret, move)) {
            _settle(game, msg.sender, challengedPlayer, Result.ChallengerChickenOut, keepIt);
        }

        // Determine the winner
        Result result;
        if (game.challengedMove == move) {
            result = Result.Draw;
            _settle(game, msg.sender, challengedPlayer, Result.Draw, keepIt);
        } else if (
            (game.challengedMove == Move.Rock && move == Move.Scissors) ||
            (game.challengedMove == Move.Paper && move == Move.Rock) ||
            (game.challengedMove == Move.Scissors && move == Move.Paper)
        ) {
            result = Result.ChallengedWin;
            _settle(game, msg.sender, challengedPlayer, Result.ChallengedWin, keepIt);
        } else {
            result = Result.ChallengerWin;
            _settle(game, msg.sender, challengedPlayer, Result.ChallengerWin, keepIt);
        }
    }

    /**
     * @notice Verify the commitment hash. This is a utility function to help you test the logic to craft the commitment hash.
     * 
     * @dev The commitment hash is created using keccak256(abi.encodePacked(_move, _secret)).
     * 
     * @param _commitment The commitment hash.
     * @param _secret The secret used to create the commitment hash.
     * @param _move The move of the player used to create the commitment hash (Rock, Paper, or Scissors).
     */
    function verifyCommitment(
        bytes32 _commitment,
        string calldata _secret,
        Move _move
    ) external pure returns (bool) {
        return _verifyCommitment(_commitment, _secret, _move);
    }

    /**
     * @notice Verify the commitment hash.
     * 
     * @dev The commitment hash is created using keccak256(abi.encodePacked(_move, _secret)).
     * 
     * @param _commitment The commitment hash.
     * @param _secret The secret used to create the commitment hash.
     * @param _move The move of the player used to create the commitment hash (Rock, Paper, or Scissors).
     */
    function _verifyCommitment(
        bytes32 _commitment,
        string calldata _secret,
        Move _move
    ) internal pure returns (bool) {
        return keccak256(abi.encodePacked(_move, _secret)) == _commitment;
    }

    /**
     * @dev The function settle the game according to the provided result. The function updates the player statistics 
     * and transfers the pledged ERC20 tokens to the winner.
     * 
     * @param challenger The address of the player who challenged the sender.
     * @param challengedPlayer The address of the player being challenged.
     * @param result The result of the game.
     * @param keepIt If true, the contract keeps the pledged ERC20 tokens. This is useful in case the transfer fails to unstuck the game.
     */
    function _settle(Game storage game, address challenger, address challengedPlayer, Result result, bool keepIt) internal {

        // Temp. store the pledge amount to be transferred back to the challenged player
        address challengerToken = game.challengerErc20Token;
        address challengedToken = game.challengedErc20Token;
        uint256 challengerAmount = game.challengerErc20Pledge;
        uint256 challengedAmount = game.challengedErc20Pledge;
        uint256 gameId = game.id;
        
        // Reset the game state
        delete games[challenger][challengedPlayer];
        
        // Redistribute the pledged ERC20 tokens to the players and update their stats according the result
        if (result == Result.ChallengerWin) {
            // Challenger wins and get all the tokens
            playerStats[challenger].wins++;
            playerStats[challengedPlayer].losses++;
            _distribute(challenger, challengerToken, challenger, challengerAmount, challengedPlayer, challengedToken, challenger, challengedAmount, keepIt);
        } else if (result == Result.ChallengedWin) {
            // Challenged player wins and get all the tokens
            playerStats[challengedPlayer].wins++;
            playerStats[challenger].losses++;
            _distribute(challenger, challengerToken, challengedPlayer, challengerAmount, challengedPlayer, challengedToken, challengedPlayer, challengedAmount, keepIt);
        } else if (result == Result.Draw) {
            // Draw, both players get their tokens back
            playerStats[challenger].draws++;
            playerStats[challengedPlayer].draws++;
            _distribute(challenger, challengerToken, challenger, challengerAmount, challengedPlayer, challengedToken, challengedPlayer, challengedAmount, keepIt);
        } else if (result == Result.ChallengerChickenOut) {
            // Challenger chicken out and challenged player gets all the tokens
            playerStats[challenger].chickenOuts++;
            _distribute(challenger, challengerToken, challengedPlayer, challengerAmount, challengedPlayer, challengedToken, challengedPlayer, challengedAmount, keepIt);
        } else if (result == Result.ChallengedChickenOut) {
            // Challenged player chicken out. Challenger gets all the tokens
            playerStats[challengedPlayer].chickenOuts++;
            _distribute(challenger, challengerToken, challenger, challengerAmount, challengedPlayer, challengedToken, challenger, challengedAmount, keepIt);
        } else {
            revert("Invalid result");
        }
        emit GameFinished(gameId, challenger, challengedPlayer, result);
    }

    /**
     * @dev Distribute the pledged ERC20 tokens to the players.
     * @param challengerPledgeTo Address of the player to receive the challenger's pledge.
     * @param challengerPledge  Address of the player to receive the challenger's pledge.
     * @param challengedPledgeTo Amount of the pledged ERC20 token to be transferred to the challenged player.
     * @param challengedPledge Amount of the pledged ERC20 token to be transferred to the challenged player.
     * @param keepIt If true, the contract keeps the pledged ERC20 tokens. This is useful in case the transfer fails to unstuck the game.
     */
    function _distribute(address challenger, address challengerErc20Token,address challengerPledgeTo, uint256 challengerPledge, address challengedPlayer, address challengedErc20Token, address challengedPledgeTo, uint256 challengedPledge, bool keepIt) internal {
        if (challengerPledge > 0 && !keepIt) {
            require(IERC20(challengerErc20Token).transferFrom(challenger, challengerPledgeTo, challengerPledge), "Transfer of the challenger's pledge failed");
        }
        if (challengedPledge > 0 && !keepIt) {
            require(IERC20(challengedErc20Token).transferFrom(challengedPlayer, challengedPledgeTo, challengedPledge), "Transfer of the challenged's pledge failed");
        }
    }
}
