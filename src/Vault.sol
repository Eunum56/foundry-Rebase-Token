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

import {IRebaseToken} from "./Interfaces/IRebaseToken.sol";

contract Vault {
    // We need to pass the token(Rebase Token) address to the constructor
    // Create a deposit function that minsts tokens to the user equal to the amount of ETH the user has sent
    // Create a redeem function that burns the tokens from the user and send the user ETH
    // Create a way to add rewards to the vault


    // ERRORS
    error Vault__RedeemFailed();
    error Vault__AmountShouldBeMoreThanZero();


    // STATE VARIABLES
    IRebaseToken private immutable i_rebaseToken;


    // EVENTS
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);


    // MODIFIERS


    // FUNCTIONS
    constructor(IRebaseToken rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    receive() external payable {}

    // EXTERNAL FUNCTIONS


    /**
     * @notice Allows users to deposit ETH into the vault and mint themselfs RebaseTokens
     */
    function deposit() external payable {
        // We need to use the amount of ETH user has sent to mint tokens to the user
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }


    /**
     * @notice Allows user to redeem their Rebase Tokens for ETH
     * @param amount The amount of Rebase Tokens to redeem
     */
    function redeem(uint256 amount) external {
        require(amount > 0, Vault__AmountShouldBeMoreThanZero());
        // 1 We need to burn the msg.sender(user) tokens
        i_rebaseToken.burn(msg.sender, amount);

        // 2 We need to send the user ETH
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, Vault__RedeemFailed());
        emit Redeem(msg.sender, amount);
    }



    // PUBLIC FUNCTIONS



    // INTERNAL FUNCTIONS



    // PRIVATE FUNCTIONS



    // GETTERS

    /**
     * @notice Get the address of Rebase Token
     * @return The address of Rebase Token
     */
    function getRebaseTokenAddress() external view returns(address){
        return address(i_rebaseToken);
    }
}