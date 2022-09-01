// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IHORDEToken {
    function balanceOf(address account) external view returns (uint256);
    function tokenTransfer(address sender, address recipient, uint256 amount) external;
    function approve(address spender, uint value) external returns (bool);
}
