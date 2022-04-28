// SPDX-License-Identifier: MIT

/** What do we want to do?
1 - People be able to stake and lock tokens on our smart contract
2 - People be able to withdraw/unlock/unstake their staked tokens out of the contract
3 - People be able to claim their reward tokens
4 - What's a good reward mechanism/math?
 */

pragma solidity 0.8.7;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

error Staking__TranferFailed();
error Staking__NeedsMoreThanZero();

contract Staking {
	// * To specify the ERC20 token, we will use openzeppelin-solidity/contracts/token/IERC20/IERC20.sol
	IERC20 public s_stakingToken; // The staking token (s_) is for "storage" meaning variable (read and write)
	IERC20 public s_rewardToken; // The reward token

	// Address maps to know how much they stake
	mapping(address => uint256) public s_balances;

	// How much each address has been paid
	mapping(address => uint256) public s_userRewardPerTokenPaid;

	// A mapping of how much rewards each address has to claim
	mapping(address => uint256) public s_rewards;

	// Total supply of the staking token
	uint256 public s_totalSupply;

	uint256 public s_rewardPerTokenStored;
	uint256 public s_lastUpdateTime;
	uint256 public constant REWARD_RATE = 100;

	// Create a modifier to update rewards for some address account user
	modifier updateReward(address account) {
		// How much is the reward for token
		// get the last timestamp
		// 12 - 1h, user earned X tokens
		s_rewardPerTokenStored = rewardPerToken();
		s_lastUpdateTime = block.timestamp;
		// Update the balance of the account
		s_rewards[account] = earned(account);
		s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
		_; // end of the modifier
	}

	modifier moreThanZero(uint256 amount) {
		if (amount == 0) {
			revert Staking__NeedsMoreThanZero();
		}
		_;
	}

	constructor(address stakingToken, address rewardToken) {
		s_stakingToken = IERC20(stakingToken);
		s_rewardToken = IERC20(rewardToken);
	}

	function earned(address account) public view returns (uint256) {
		uint256 currentBalance = s_balances[account];
		// How much they have been paid already
		uint256 amountPaid = s_userRewardPerTokenPaid[account];
		uint256 currentRewardPerToken = rewardPerToken();
		uint256 pastRewards = s_rewards[account];

		uint256 _earned = ((currentBalance * (currentRewardPerToken - amountPaid)) / 1e18) +
			pastRewards;
		return _earned;
	}

	// Based on how long it's been during this most recent snapshop
	function rewardPerToken() public view returns (uint256) {
		if (s_totalSupply == 0) {
			return s_rewardPerTokenStored;
		}
		return
			s_rewardPerTokenStored +
			((((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) / s_totalSupply));
	}

	// ? 1- Staking part of the contract
	/* Do we allow any tokens?
 Then => stake(uint256, address token) => The address of the specific token to be staked
	*/
	// * On that case we will allow just specific token to be stake
	function stake(uint256 amount) external updateReward(msg.sender) moreThanZero(amount) {
		// Keep track of how much this user has staked
		s_balances[msg.sender] = s_balances[msg.sender] + amount;
		// Keep track of how much token we have total
		s_totalSupply = s_totalSupply + amount;
		// TODO => Emit an event
		// Transfer the tokens to this contract
		bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
		if (!success) {
			revert Staking__TranferFailed();
		}
	}

	// ? 2- Withdraw part of the contract
	function withdraw(uint256 amount) external updateReward(msg.sender) moreThanZero(amount) {
		s_balances[msg.sender] = s_balances[msg.sender] - amount;
		s_totalSupply = s_totalSupply - amount;
		bool success = s_stakingToken.transfer(msg.sender, amount);
		if (!success) {
			revert Staking__TranferFailed();
		}
	}

	// ? 3- Claim part of the contract
	function claimReward() external updateReward(msg.sender) {
		uint256 reward = s_rewards[msg.sender];
		bool success = s_rewardToken.transfer(msg.sender, reward);
		if (!success) {
			revert Staking__TranferFailed();
		}

		// How much reward do they get?
		//
		// The contract is going to emit X tokens per second
		// And disperse them to all token stakers
		//
		// 100 reward tokens / second
		// staked: 50 staked tokens, 20 staked okens, 30 staked tokens
		// rewards> 50 reward tokens, 20 reward	tokens, 30 reward tokens
		//
		// staked: 100, 50, 20, 30 (total = 200)
		// rewards: 50, 25, 10, 15 (total = 100)
		// another example...:
		// 5 seconds, 1 person had 100 token staked = reward 500 tokens
		// 6 seconds, 2 persons had 100 tokens staked each
		// person 1: 550
		// person 2: 50
		//
		// ok between second 1 and 5, person 1 got 500 tokens
		// ok at second 6 on, person 1 gets 50 tokens now
	}
}
