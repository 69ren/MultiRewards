// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {MultiRewards} from "../contracts/MultiRewards.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MultiRewardsTest is Test {
    function setUp() external {
        vm.createSelectFork("fantom", 76661186);
    }
}
