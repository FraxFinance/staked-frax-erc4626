// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../BaseTest.sol";

contract TestDeployment is BaseTest {
    /// FEATURE: deployment script

    using StakedFraxStructHelper for *;

    function setUp() public {
        /// BACKGROUND: deploy the StakedFrax contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        defaultSetup();
    }

    function test_Deploy() public {
        /// SCENARIO: The deployment is as expected after the deploy script is used

        /// WHEN: StakedFrax contract is deployed

        /// THEN: A totalSupply of Shares is 1000
        assertEq(stakedFrax.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// THEN: storedTotalAssets is 1000
        assertEq(stakedFrax.storedTotalAssets(), 1000 ether, "setup: storedTotalAssets should be 1000");

        /// THEN: cycleEnd next full cycle multiplied from unix epoch
        assertEq(
            stakedFrax.__rewardsCycleData().cycleEnd,
            ((block.timestamp + rewardsCycleLength) / rewardsCycleLength) * rewardsCycleLength,
            "setup: cycleEnd should be next full cycle multiplied from unix epoch"
        );

        /// THEN: lastSync is now
        assertEq(stakedFrax.__rewardsCycleData().lastSync, block.timestamp, "setup: lastSync should be now");

        /// THEN: rewardsForDistribution is 0
        assertEq(stakedFrax.__rewardsCycleData().rewardCycleAmount, 0, "setup: rewardsForDistribution should be 0");

        /// THEN: lastDistributionTime is now
        assertEq(stakedFrax.lastRewardsDistribution(), block.timestamp, "setup: lastDistributionTime should be now");

        /// THEN: rewardsCycleLength is 7 days
        assertEq(stakedFrax.REWARDS_CYCLE_LENGTH(), 7 days, "setup: rewardsCycleLength should be 7 days");
    }
}
