// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {MultiRewards} from "../contracts/MultiRewards.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IMasterChef} from "../contracts/interfaces/IMasterChef.sol";

contract MultiRewardsTest is Test {
    MultiRewards rewarder;
    IMasterChef masterChef;
    IERC20 pool;
    IERC20 wFtm;
    IERC20 beets;

    address owner;
    address user;

    function setUp() external {
        vm.createSelectFork("fantom", 76661186);
        pool = IERC20(0x838229095fa83BCD993eF225d01a990E3Bc197A8);
        wFtm = IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
        beets = IERC20(0xF24Bcf4d1e507740041C9cFd2DddB29585aDCe1e);

        owner = address(1);
        user = address(2);

        masterChef = IMasterChef(0x8166994d9ebBe5829EC86Bd81258149B87faCfd3);

        rewarder = new MultiRewards(
            owner,
            address(pool),
            address(masterChef),
            address(beets),
            125,
            "Test",
            "TST"
        );
    }

    function testDeposit() external {
        vm.startPrank(owner);
        deal(address(pool), owner, 1e18);
        pool.approve(address(rewarder), type(uint256).max);
        rewarder.depositAll();

        assertEq(rewarder.balanceOf(owner), 1e18);
        assertEq(rewarder.totalSupply(), 1e18);
        assertEq(pool.balanceOf(owner), 0);
    }

    function testWithdraw() external {
        vm.startPrank(owner);
        deal(address(pool), owner, 1e18);
        pool.approve(address(rewarder), type(uint256).max);
        rewarder.depositAll();

        rewarder.withdrawAll();
        assertEq(rewarder.balanceOf(owner), 0);
        assertEq(rewarder.totalSupply(), 0);
        assertEq(pool.balanceOf(owner), 1e18);
    }

    function testDistribution() external {
        vm.startPrank(owner);
        deal(address(wFtm), owner, 604800 * 1e18);
        deal(address(pool), owner, 1e18);

        pool.approve(address(rewarder), type(uint256).max);
        wFtm.approve(address(rewarder), type(uint256).max);

        rewarder.notifyRewardAmount(address(wFtm), 604800 * 1e18);
        assertEq(wFtm.balanceOf(owner), 0);
        assertEq(wFtm.balanceOf(address(rewarder)), 604800 * 1e18);
        rewarder.depositAll();

        MultiRewards.Reward memory rewardData = rewarder.rewardData(
            address(wFtm)
        );

        assertEq(rewardData.rewardRate, 1e18);
        assertEq(rewardData.periodFinish, block.timestamp + 604800);
        assertEq(rewardData.lastUpdateTime, block.timestamp);
        assertEq(rewardData.rewardPerTokenStored, 0);

        vm.warp(block.timestamp + 1);

        assertEq(rewarder.earned(address(wFtm), owner), 1e18);
        assertEq(rewarder.rewardPerToken(address(wFtm)), 1e18);

        rewarder.getReward();

        assertEq(wFtm.balanceOf(owner), 1e18);

        rewardData = rewarder.rewardData(address(wFtm));
        assertEq(rewarder.userRewardPerTokenStored(owner, address(wFtm)), 1e18);
        assertEq(rewardData.rewardRate, 1e18);
        assertEq(rewardData.lastUpdateTime, block.timestamp);
        assertEq(rewardData.rewardPerTokenStored, 1e18);

        vm.warp(block.timestamp + 1);
        assertEq(rewarder.earned(address(wFtm), owner), 1e18);
        assertEq(rewarder.rewardPerToken(address(wFtm)), 2e18);

        rewarder.getReward();

        assertEq(wFtm.balanceOf(owner), 2e18);
        rewardData = rewarder.rewardData(address(wFtm));
        assertEq(rewardData.rewardPerTokenStored, 2e18);
    }
}
