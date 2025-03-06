// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.4;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Mohd Muzammil
 * @notice A cross-chain rebase token that incentivizes users to deposit into a vault and gain interest rewards.
 *         The interest can only decrease over time, and each user’s deposit gets locked in at the global interest rate at the time of deposit.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    // ERRORS
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    // STATE VARIABLES
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8; // 10^-8 == 1 / 10^8
        // Global interest rate per second, scaled (for example, 5e10 means 5 * 10^10 per second)

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    uint256 private constant PRECISION_FACTOR = 1e18; // Precision factor to maintain fixed-point arithmetic

    mapping(address => uint256) private s_userInterestRate; // Each user’s interest rate is recorded at the time of deposit.

    mapping(address => uint256) private s_userLastUpdatedTimestamp; // Records the last time a user's balance was updated (mint, burn, transfer).

    // EVENTS
    event InterestRateSet(uint256 oldInterestRate, uint256 newInterestRate);

    // CONSTRUCTOR
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    // EXTERNAL FUNCTIONS

    /**
     * @notice Update the global interest rate.
     * @dev The new interest rate must be higher than the current rate (i.e., interest can only decrease for depositors).
     * @param newInterestRate The new global interest rate to set.
     */
    function setInterestRate(uint256 newInterestRate) external onlyOwner {
        // The require statement checks that newInterestRate is greater than the current rate.
        // This might seem counterintuitive, but here "interest rate" is used in the math such that a higher number results in lower effective yield.
        require(
            newInterestRate < s_interestRate, RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, newInterestRate)
        );
        // Emit event with the old and new rates (note: s_interestRate is updated after emitting the event here, which might be something to consider).
        emit InterestRateSet(s_interestRate, newInterestRate);
        s_interestRate = newInterestRate;
    }

    /**
     * @notice Mint tokens for a user when they deposit into the vault.
     * @param to The address to mint tokens to.
     * @param amount The number of tokens (principal) to mint.
     * @dev Before minting, accrued interest is calculated and minted.
     */
    function mint(address to, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        // First, mint any accrued interest for the user.
        _mintAccruedInterest(to);
        // Set the user's interest rate to the current global rate at deposit time.
        s_userInterestRate[to] = s_interestRate;
        // Mint the principal tokens.
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from a user when they withdraw from the vault.
     * @param from The address to burn tokens from.
     * @param amount The number of tokens to burn. If the amount is the maximum uint256 value, burn the entire balance.
     */
    function burn(address from, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        // Mint any accrued interest before burning.
        _mintAccruedInterest(from);
        // Burn the tokens.
        _burn(from, amount);
    }

    function grantMintAndBurnRole(address account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, account);
    }

    // PUBLIC FUNCTIONS

    /**
     * @notice Returns the user's balance including accrued interest.
     * @param user The address of the user.
     * @return The effective balance (principal + accrued interest).
     */
    function balanceOf(address user) public view override returns (uint256) {
        // Get the base (principle) balance minted to the user (without accrued interest).
        uint256 principle = super.balanceOf(user);
        // Calculate the accumulated interest multiplier using time elapsed.
        uint256 interestMultiplier = _calculateUserAccumulatedInterestSinceLastUpdate(user);
        // The effective balance is the principle multiplied by the multiplier, then scaled down by the PRECISION_FACTOR.
        return principle * interestMultiplier / PRECISION_FACTOR;
    }

    /**
     * @notice Transfer tokens from msg.sender to a recipient.
     * @param recipient The address to transfer tokens to.
     * @param amount The amount of tokens to transfer. If max uint256 is specified, transfer entire balance.
     * @return True if the transfer was successful.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        // First, update the accrued interest for both sender and recipient.
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(recipient);

        // If amount is max uint256, interpret it as transferring the entire balance.
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }

        // If the recipient had no balance before, inherit the sender's interest rate.
        if (balanceOf(recipient) == 0) {
            s_userInterestRate[recipient] = s_userInterestRate[msg.sender];
        }

        // Execute the standard ERC20 transfer.
        return super.transfer(recipient, amount);
    }

    /**
     * @notice Transfer tokens on behalf of a sender.
     * @param sender The address to transfer tokens from.
     * @param recipient The address to receive the tokens.
     * @param amount The amount to transfer. If max uint256 is specified, transfer the full balance.
     * @return True if the transfer was successful.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        // Update accrued interest for both sender and recipient.
        _mintAccruedInterest(sender);
        _mintAccruedInterest(recipient);

        // Interpret max value as "transfer all tokens".
        if (amount == type(uint256).max) {
            amount = balanceOf(sender);
        }

        // If the recipient had no balance before, inherit the sender's interest rate.
        if (balanceOf(recipient) == 0) {
            s_userInterestRate[recipient] = s_userInterestRate[sender];
        }

        // Execute the standard ERC20 transferFrom.
        return super.transferFrom(sender, recipient, amount);
    }

    // INTERNAL FUNCTIONS

    /**
     * @notice Mint the accrued interest for a user since their last interaction (mint, burn, or transfer).
     * @param user The address to update.
     * @dev This function calculates the difference between the current effective balance and the principle balance,
     *      then mints that difference as "interest".
     */
    function _mintAccruedInterest(address user) internal {
        // (1) Get the current principle balance (without interest)
        uint256 previousPrincipleBalance = super.balanceOf(user);
        // (2) Get the current effective balance (with accrued interest)
        uint256 currentBalance = balanceOf(user);
        // The increase is the interest accrued.
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // Update the user's last updated timestamp to now.
        s_userLastUpdatedTimestamp[user] = block.timestamp;
        // Mint the interest tokens so that principle becomes updated.
        _mint(user, balanceIncrease);
    }

    /**
     * @notice Calculates the interest multiplier based on time elapsed since the last update.
     * @param user The address to calculate for.
     * @return A multiplier (with PRECISION_FACTOR scaling) representing accrued interest.
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address user) internal view returns (uint256) {
        // Calculate time elapsed since last update.
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[user];
        // The formula uses linear growth: multiplier = 1 + (interestRate * timeElapsed)
        // Multiplication with PRECISION_FACTOR ensures fixed-point math accuracy.
        uint256 linearInterest = PRECISION_FACTOR + (s_userInterestRate[user] * timeElapsed);
        return linearInterest;
    }

    // GETTERS

    /**
     * @notice Returns the current global interest rate for future deposits.
     * @return The global interest rate.
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Returns the interest rate that was locked in for a specific user.
     * @param user The user's address.
     * @return The user's interest rate.
     */
    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

    /**
     * @notice Returns the last timestamp when the user's balance was updated.
     * @param user The user's address.
     * @return The timestamp of the last update.
     */
    function getUserLastUpdatedTimestamp(address user) external view returns (uint256) {
        return s_userLastUpdatedTimestamp[user];
    }

    /**
     * @notice Returns the principle balance of a user (without accrued interest).
     * @param user The user's address.
     * @return The principle balance.
     */
    function getPrincipleBalance(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }
}
