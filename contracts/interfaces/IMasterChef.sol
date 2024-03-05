// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMasterChef {
    function deposit(uint256 _pid, uint256 _amount, address _to) external;

    function withdrawAndHarvest(
        uint256 _pid,
        uint256 _amount,
        address _to
    ) external;

    function harvest(uint256 _pid, address _to) external;
}
