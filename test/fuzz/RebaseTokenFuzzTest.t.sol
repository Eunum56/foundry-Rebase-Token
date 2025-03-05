// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/Interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract RebaseTokenTest is Test {
    RebaseToken rebaseToken;
    Vault vault;

    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");

    event Redeem(address indexed user, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));

        vm.stopPrank();
    }

    function addRewardToValut(uint256 amount) public {
        (bool success,) = address(vault).call{value: amount}("");
        require(success);
    }

        // DEPOSIT TESTS
    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        // 2. check our rebase token balance
        uint256 startingBalance = rebaseToken.balanceOf(user);
        assertEq(startingBalance, amount);

        // 3. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startingBalance);

        // 4. warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endingBalance = rebaseToken.balanceOf(user);
        assertGt(endingBalance, middleBalance);

        assertApproxEqAbs(endingBalance - middleBalance, middleBalance - startingBalance, 1);

        vm.stopPrank();
    }

    // REDEEM TESTS
    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);

        // 2. Redeem
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        // 1. Deposit
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // 2. Warp the time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTimePassed = rebaseToken.balanceOf(user);
        // 2(b) Adds the rewards to the vault
        vm.deal(owner, balanceAfterSomeTimePassed - depositAmount);
        vm.prank(owner);
        addRewardToValut(balanceAfterSomeTimePassed - depositAmount);

        // 3. Redeem
        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 userETHBalance = address(user).balance;

        assertEq(userETHBalance, balanceAfterSomeTimePassed);
        assertGt(userETHBalance, depositAmount);
    }


    // TRANSFER TESTS
    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e10, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // 1. Deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);

        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // Owner reduces the interest rate.
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // Transfer
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        uint256 userBalanceAfterAmountSend = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterAmountReceived = rebaseToken.balanceOf(user2);

        assertEq(userBalanceAfterAmountSend, userBalance - amountToSend);
        assertEq(user2BalanceAfterAmountReceived, amountToSend);

        // Check the user interest rate has been inherited (5e10 not 4w10)
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }


    // TRANSFER FROM TESTS
    function testTransferFrom(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e10, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // 1. Deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);

        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // Owner reduces the interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // 2. Give user2 Allowance
        vm.prank(user);
        IERC20(rebaseToken).approve(user2, amountToSend);

        // 3. Transfer
        vm.prank(user2);
        rebaseToken.transferFrom(user, user2, amountToSend);

        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterAmountReceived = rebaseToken.balanceOf(user2);

        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterAmountReceived, amountToSend);

        // 4. Check the interest rate inherited (5e10 not 4e10)
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }


    function testOnlyOwnerCanSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }


    function testPrincipleBalance(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        assertEq(rebaseToken.getPrincipleBalance(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.getPrincipleBalance(user), amount);
    }


    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate + 1, type(uint96).max);

        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterestRate);

        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}