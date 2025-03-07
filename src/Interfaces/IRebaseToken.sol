// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IRebaseToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}
