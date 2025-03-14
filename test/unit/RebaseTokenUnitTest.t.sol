// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/Interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RejectingReceiver {
    fallback() external payable {
        revert();
    }
}

contract RebaseTokenTest is Test {
    RebaseToken rebaseToken;
    Vault vault;
    RejectingReceiver rejectingReceiver;

    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");

    event Redeem(address indexed user, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        rejectingReceiver = new RejectingReceiver();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));

        vm.stopPrank();
    }

    function addRewardToValut(uint256 amount) public {
        (bool success,) = address(vault).call{value: amount}("");
        require(success);
    }

    // REDEEM TESTS
    function testRedeemRevertsIfAmountIsZero() public {
        vm.prank(owner);
        vm.expectRevert(Vault.Vault__AmountShouldBeMoreThanZero.selector);
        vault.redeem(0);
    }

    function testRedeemEmitEvent() public {
        // 1. Deposit
        vm.deal(user, 1e10);
        vm.prank(user);
        vault.deposit{value: 1e10}();
        assertEq(rebaseToken.balanceOf(user), 1e10);

        // 2. Redeem
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit Redeem(user, 1e10);
        vault.redeem(1e10);

        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, 1e10);
    }

    function testRedeemRevertsIfRedeemFails() public {
        // 1. Deposit
        vm.deal(user, 1e10);
        vm.prank(user);
        vault.deposit{value: 1e10}();
        assertEq(rebaseToken.balanceOf(user), 1e10);

        // Transfer tokens to contract to get reverted
        vm.prank(user);
        rebaseToken.transfer(address(rejectingReceiver), 1e10);

        // 2. Redeem with RejectingReceiver contract
        vm.prank(address(rejectingReceiver));
        vm.expectRevert(Vault.Vault__RedeemFailed.selector);
        vault.redeem(1e10);
    }

    // TRANSFER TESTS
    function testTransferUin256MaxAmount() public {
        // 1. Deposit
        vm.deal(user, 1e10);
        vm.prank(user);
        vault.deposit{value: 1e10}();

        assertEq(rebaseToken.balanceOf(user), 1e10);
        uint256 userBalance = rebaseToken.balanceOf(user);

        vm.prank(user);
        // 2. Sending Max uint256 amount
        rebaseToken.transfer(user2, type(uint256).max);

        assertEq(rebaseToken.balanceOf(user2), userBalance);
    }

    // TRANSFER FROM TESTS
    function testTransferFromUint256MaxAmount() public {
        // 1. Deposit
        vm.deal(user, 1e10);
        vm.prank(user);
        vault.deposit{value: 1e10}();

        assertEq(rebaseToken.balanceOf(user), 1e10);
        uint256 userBalance = rebaseToken.balanceOf(user);

        // 2. Give user2 allowance with max uint256
        vm.prank(user);
        IERC20(rebaseToken).approve(user2, userBalance);

        // 3. Transfer with max uint256
        vm.prank(user2);
        rebaseToken.transferFrom(user, user2, type(uint256).max);

        assertEq(rebaseToken.balanceOf(user2), userBalance);
    }

    function testOnlyOwnerCanCallMintAndBurn() public {
        vm.prank(user);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(user, 100, rebaseToken.getInterestRate());

        vm.prank(user);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(user, 100);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testUserLastTimeUpdatedTimestamp() public {
        // 1. Deposit to set user timestamp
        vm.deal(user, 1e10);
        vm.prank(user);
        uint256 firstUserTImestamp = block.timestamp;
        vault.deposit{value: 1e2}();
        assertEq(block.timestamp, firstUserTImestamp);

        // 2. Increase timestamp with vm.warp
        vm.warp(block.timestamp + 1 hours);
        vm.prank(user);
        vault.deposit{value: 1e2}();
        assertEq(rebaseToken.getUserLastUpdatedTimestamp(user), block.timestamp);
    }
}
