// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Fees
 * @author degengineering.ink
 * @notice This contract provides basic fee management functionalities restricted to the owner of the contract and a collectFee 
 * modifier which can be used by payable functions to require and collect a flat service fee without changing the function code.
 */
contract Fees is Ownable, ReentrancyGuard {

    // Fee rquested in weis
    uint256 private _fee;

    /**
     * @notice Emitted when the fee is updated.
     * @param oldFee The old fee.
     * @param newFee The new fee.
     */
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    /**
     * @notice Emitted when the fees are withdrawn.
     * @param owner The address of the owner.
     * @param amount The amount withdrawn.
     */
    event FeesWithdrawn(address indexed owner, uint256 amount);

    /**
     * @notice Storage structure for the contract.
     * @param fee The fee requested in wei.
     */
    constructor(uint256 fee) Ownable(msg.sender) {
        _fee = fee;
        emit FeeUpdated(0, fee);
    }

    /**
     * @notice Modifier to collect a service fee for contract execution and return excess of funds.
     *
     * @dev This modifier ensures a sufficient service fee is provided by the sender
     * before executing the contract logic. The excess amount is refunded to the sender
     * after the execution of the contract logic.
     */
    modifier collectFee() {
        // Check a sufficient fee is provided
        require(msg.value >= _fee, "Insufficient service fee provided");
        // Execute contract logic
        _;
        // Refund any excess directly to the sender
        if (msg.value > _fee) {
            payable(msg.sender).transfer(msg.value - _fee);
        }
    }

    /**
     * @notice Updates the service fee.
     * @dev This function should be restricted to authorized users.
     * @param newFee The new fee to be set.
     */
    function updateFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = _fee;
        _updateFee(newFee);
        emit FeeUpdated(oldFee, _fee);
    }

    /**
     * @notice Return the current requested fee.
     * @return The current fee in wei.
     */
    function currentFee() external view returns (uint256) {
        return _fee;
    }

    /**
     * @notice Withdraws the full contract balance to the owner.
     * @dev This function should be restricted to authorized users.
     * @return The amount withdrawn, expressed in wei.
     */
    function withdrawFees() external onlyOwner nonReentrant returns (uint256) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
        emit FeesWithdrawn(owner(), balance);
        return balance;
    }

    /**
     * @notice Internal function to update the fee.
     * @param newFee The new fee to be set.
     */
    function _updateFee(uint256 newFee) internal {
        require(newFee > 0, "Fee must be greater than 0");
        _fee = newFee;
    }
}