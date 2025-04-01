// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title WRAMBLING Token
 * @author degengineering.ink
 * @notice The memecoin of memecoins. One deploy. Infinite dreams.
 */
contract Wrambling is ERC20 {
    constructor() ERC20("WRAMBLING", "WRAMBLING") {
        _mint(msg.sender, type(uint256).max);
    }
}
