// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMasterChef} from "./interfaces/IMasterChef.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {
    AccessControlEnumerable
} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract MultiRewards is ERC20, ReentrancyGuard, AccessControlEnumerable {
    error ZeroAmount();
    error Shutdown();

    struct Reward {
        uint256 rewardRate;
        uint256 periodFinish;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    bytes32 constant NOTIFIER_ROLE = keccak256("NOTIFIER_ROLE");

    address public immutable stakingToken;
    address public immutable masterChef;
    address public immutable beets;

    uint256 public immutable poolId;
    uint256 internal constant DURATION = 7 days;
    uint256 internal constant PRECISION = 10 ** 18;

    uint256 public unsyncedBeets;

    address[] internal rewards;
    mapping(address token => Reward) internal _rewardData;
    mapping(address user => mapping(address token => uint256 rewardPerToken))
        public userRewardPerTokenStored;
    mapping(address user => mapping(address token => uint256 reward))
        public storedRewardsPerUser;
    mapping(address token => bool) public isReward;

    bool public isShutdown;

    event Deposit(address indexed from, uint256 amount);

    event Withdraw(address indexed from, uint256 amount);

    event NotifyReward(
        address indexed from,
        address indexed reward,
        uint256 amount
    );

    event ClaimRewards(
        address indexed from,
        address indexed reward,
        uint256 amount
    );

    event IsShutdown(bool status);

    constructor(
        address _admin,
        address _stakingtoken,
        address _masterChef,
        address _beets,
        uint256 _poolId,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) ReentrancyGuard() {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(NOTIFIER_ROLE, _admin);

        stakingToken = _stakingtoken;
        masterChef = _masterChef;
        beets = _beets;
        poolId = _poolId;

        rewards.push(_beets);
        isReward[_beets] = true;

        IERC20(stakingToken).approve(_masterChef, type(uint256).max);
    }

    modifier updateReward(address account) {
        _updateReward(account);
        _;
    }

    /// @dev compiled with via-ir, caching is less efficient
    function _updateReward(address account) internal {
        for (uint256 i; i < rewards.length; i++) {
            _rewardData[rewards[i]].rewardPerTokenStored = rewardPerToken(
                rewards[i]
            );
            _rewardData[rewards[i]].lastUpdateTime = lastTimeRewardApplicable(
                rewards[i]
            );
            if (account != address(0)) {
                storedRewardsPerUser[account][rewards[i]] = earned(
                    rewards[i],
                    account
                );
                userRewardPerTokenStored[account][rewards[i]] = _rewardData[
                    rewards[i]
                ].rewardPerTokenStored;
            }
        }
    }

    function rewardsList() external view returns (address[] memory _rewards) {
        _rewards = rewards;
    }

    function rewardsListLength() external view returns (uint256 _length) {
        _length = rewards.length;
    }

    /// @notice returns the last time the reward was modified or periodFinish if the reward has ended
    function lastTimeRewardApplicable(
        address token
    ) public view returns (uint256) {
        return Math.min(block.timestamp, _rewardData[token].periodFinish);
    }

    function rewardData(
        address token
    ) external view returns (Reward memory data) {
        data = _rewardData[token];
    }

    function earned(
        address token,
        address account
    ) public view returns (uint256 _reward) {
        _reward =
            ((balanceOf(account) *
                (rewardPerToken(token) -
                    userRewardPerTokenStored[account][token])) / PRECISION) +
            storedRewardsPerUser[account][token];
    }

    function getReward() external nonReentrant updateReward(msg.sender) {
        for (uint256 i; i < rewards.length; i++) {
            uint256 _reward = storedRewardsPerUser[msg.sender][rewards[i]];
            if (_reward > 0) {
                storedRewardsPerUser[msg.sender][rewards[i]] = 0;
                _safeTransfer(rewards[i], msg.sender, _reward);
                emit ClaimRewards(msg.sender, rewards[i], _reward);
            }
        }
    }

    function rewardPerToken(address token) public view returns (uint256) {
        if (totalSupply() == 0) {
            return _rewardData[token].rewardPerTokenStored;
        }
        return
            _rewardData[token].rewardPerTokenStored +
            ((lastTimeRewardApplicable(token) -
                _rewardData[token].lastUpdateTime) *
                _rewardData[token].rewardRate *
                PRECISION) /
            totalSupply();
    }

    function depositAll() external {
        deposit(_balanceOf(stakingToken, msg.sender));
    }

    function deposit(
        uint256 amount
    ) public nonReentrant updateReward(msg.sender) {
        if (amount == 0) {
            revert ZeroAmount();
        }

        if (isShutdown) {
            revert Shutdown();
        }

        _safeTransferFrom(stakingToken, msg.sender, address(this), amount);
        IMasterChef(masterChef).deposit(poolId, amount, address(this));
        _mint(msg.sender, amount);

        emit Deposit(msg.sender, amount);
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    function withdraw(
        uint256 amount
    ) internal nonReentrant updateReward(msg.sender) {
        if (amount == 0) {
            revert ZeroAmount();
        }

        _burn(msg.sender, amount);

        uint256 beetsBalance = _balanceOf(beets, address(this));

        if (!isShutdown) {
            IMasterChef(masterChef).withdrawAndHarvest(
                poolId,
                amount,
                address(this)
            );
        }

        uint256 beetsBalanceAfter = _balanceOf(beets, address(this));

        uint256 _unsyncedBeets = beetsBalanceAfter - beetsBalance;
        if (_unsyncedBeets > 0) {
            unsyncedBeets += _unsyncedBeets;
        }

        _safeTransfer(stakingToken, msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    function left(address token) public view returns (uint256) {
        if (block.timestamp >= _rewardData[token].periodFinish) return 0;
        uint256 _remaining = _rewardData[token].periodFinish - block.timestamp;
        return _remaining * _rewardData[token].rewardRate;
    }

    function notifyRewardAmount(
        address token,
        uint256 amount
    ) external updateReward(address(0)) onlyRole(NOTIFIER_ROLE) {
        if (amount == 0) {
            revert ZeroAmount();
        }

        if (!isReward[token]) {
            rewards.push(token);
            isReward[token] = true;
        }

        _rewardData[token].rewardPerTokenStored = rewardPerToken(token);

        // Check actual amount transferred for compatibility with fee on transfer tokens.
        uint256 balanceBefore = _balanceOf(token, address(this));
        _safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 balanceAfter = _balanceOf(token, address(this));
        amount = balanceAfter - balanceBefore;

        if (block.timestamp >= _rewardData[token].periodFinish) {
            _rewardData[token].rewardRate = amount / DURATION;
        } else {
            uint256 remaining = _rewardData[token].periodFinish -
                block.timestamp;
            uint256 _left = remaining * _rewardData[token].rewardRate;
            _rewardData[token].rewardRate = (amount + _left) / DURATION;
        }

        _rewardData[token].lastUpdateTime = block.timestamp;
        _rewardData[token].periodFinish = block.timestamp + DURATION;

        emit NotifyReward(msg.sender, token, amount);
    }

    function poke() external updateReward(address(0)) onlyRole(NOTIFIER_ROLE) {
        uint256 beetsBalance = _balanceOf(beets, address(this));
        IMasterChef(masterChef).harvest(poolId, address(this));
        uint256 beetsBalanceAfter = _balanceOf(beets, address(this));

        uint256 _unsyncedBeets = beetsBalanceAfter - beetsBalance;
        _unsyncedBeets += unsyncedBeets;

        if (_unsyncedBeets > 0) {
            unsyncedBeets = 0;

            _rewardData[beets].rewardPerTokenStored = rewardPerToken(beets);

            if (block.timestamp >= _rewardData[beets].periodFinish) {
                _rewardData[beets].rewardRate = _unsyncedBeets / DURATION;
            } else {
                uint256 remaining = _rewardData[beets].periodFinish -
                    block.timestamp;
                uint256 _left = remaining * _rewardData[beets].rewardRate;
                _rewardData[beets].rewardRate =
                    (_unsyncedBeets + _left) /
                    DURATION;
            }

            _rewardData[beets].lastUpdateTime = block.timestamp;
            _rewardData[beets].periodFinish = block.timestamp + DURATION;

            emit NotifyReward(msg.sender, beets, _unsyncedBeets);
        }
    }

    function recoverTokens(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).transfer(to, amount);
    }

    function shutDown(bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance;
        if (status) {
            (balance, ) = IMasterChef(masterChef).userInfo(
                poolId,
                address(this)
            );
            IMasterChef(masterChef).withdrawAndHarvest(
                poolId,
                balance,
                address(this)
            );
            isShutdown = true;
            emit IsShutdown(true);
        } else {
            balance = IERC20(stakingToken).balanceOf(address(this));
            IMasterChef(masterChef).deposit(poolId, balance, address(this));
            isShutdown = false;
            emit IsShutdown(false);
        }
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        // if burn or mint
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
        } else {
            _updateReward(from);
            _updateReward(to);
            super._update(from, to, value);
        }
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeCall(IERC20.transfer, (to, value))
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeCall(IERC20.transferFrom, (from, to, value))
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _balanceOf(
        address token,
        address account
    ) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeCall(IERC20.balanceOf, (account))
        );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }
}
