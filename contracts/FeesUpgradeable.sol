// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @dev ERC-7201-style storage layout for upgrade safety
library FeesStorage {
    bytes32 internal constant STORAGE_SLOT = keccak256("fees.storage");

    struct Layout {
        uint256 fee;
    }

    function layout() internal pure returns (Layout storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}

/**
 * @title FeesUpgradeable
 * @author degengineering.ink
 * @notice Upgradeable contract providing fee logic and a collectFee modifier.
 */
abstract contract FeesUpgradeable is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using FeesStorage for FeesStorage.Layout;

    /// @notice Emitted when the fee is updated.
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    /// @notice Emitted when the fees are withdrawn.
    event FeesWithdrawn(address indexed owner, uint256 amount);

    /// @dev Initializer instead of constructor
    function __Fees_init(uint256 fee) internal onlyInitializing {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        _updateFee(fee);
        emit FeeUpdated(0, fee);
    }

    /**
     * @notice Modifier to collect service fee and refund excess.
     */
    modifier collectFee() {
        FeesStorage.Layout storage ds = FeesStorage.layout();
        require(msg.value >= ds.fee, "Insufficient service fee provided");
        _;
        if (msg.value > ds.fee) {
            payable(msg.sender).transfer(msg.value - ds.fee);
        }
    }

    /**
     * @notice Update the service fee (owner only).
     */
    function updateFee(uint256 newFee) external onlyOwner {
        FeesStorage.Layout storage ds = FeesStorage.layout();
        uint256 oldFee = ds.fee;
        _updateFee(newFee);
        emit FeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Return the current service fee.
     */
    function currentFee() external view returns (uint256) {
        return FeesStorage.layout().fee;
    }

    /**
     * @notice Withdraw collected fees (owner only).
     */
    function withdrawFees() external onlyOwner nonReentrant returns (uint256) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
        emit FeesWithdrawn(owner(), balance);
        return balance;
    }

    /// @dev Internal utility to update fee
    function _updateFee(uint256 newFee) internal {
        require(newFee > 0, "Fee must be greater than 0");
        FeesStorage.layout().fee = newFee;
    }
}
