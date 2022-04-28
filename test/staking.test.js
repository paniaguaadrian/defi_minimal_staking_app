const { ethers, deployments } = require('hardhat')
const { moveBlocks } = require('../utils/mode-blocks')
const { moveTime } = require('../utils/mode-time')

const SECONDS_IN_A_DAY = 86400
const SECONDS_IN_A_YEAR = SECONDS_IN_A_DAY * 365

describe('Staking test', async () => {
	let staking, rewardToken, deployer, stakeAmount

	beforeEach(async () => {
		const accounts = await ethers.getSigners()
		deployer = accounts[0]

		await deployments.fixture(['all'])
		staking = await ethers.getContract('Staking')
		rewardToken = await ethers.getContract('RewardToken')
		stakeAmount = ethers.utils.parseEther('100000')
	})

	it('Allow users to stake and claim rewards', async () => {
		await rewardToken.approve(staking.address, stakeAmount)
		await staking.stake(stakeAmount)
		const startingEarned = await staking.earned(deployer.address)
		console.log(`Starting Earned ${startingEarned}`)

		await moveTime(SECONDS_IN_A_YEAR)
		await moveBlocks(1)
		const endingEarned = await staking.earned(deployer.address)
		console.log(`Ending Earned ${endingEarned}`)
	})
})
