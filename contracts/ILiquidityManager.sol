// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface ILiquidityManager {
    function swapHordeToBusd(
        uint256 hordeAmount
    ) external;
}