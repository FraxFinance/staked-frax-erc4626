// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../BaseTest.sol";

contract TestDistributeRewards is BaseTest {
    using SavingsFraxStructHelper for *;

    /// FEATURE: rewards distribution end to end tests
    using ArrayHelper for function()[];

    address bob;
    address alice;
    address donald;

    function setUp() public virtual {
        defaultSetup();

        bob = labelAndDeal(address(1234), "bob");
        mintFraxTo(bob, 1000 ether);
        hoax(bob);
        fraxErc20.approve(savingsFraxAddress, type(uint256).max);

        alice = labelAndDeal(address(2345), "alice");
        mintFraxTo(alice, 1000 ether);
        hoax(alice);
        fraxErc20.approve(savingsFraxAddress, type(uint256).max);

        donald = labelAndDeal(address(3456), "donald");
        mintFraxTo(donald, 1000 ether);
        hoax(donald);
        fraxErc20.approve(savingsFraxAddress, type(uint256).max);
    }

    function test_Deploy() public {
        /// GIVEN: A totalSupply of Shares is 1000
        assertEq(savingsFrax.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// GIVEN: storedTotalAssets is 1000
        assertEq(savingsFrax.storedTotalAssets(), 1000 ether, "setup: storedTotalAssets should be 1000");

        /// GIVEN: cycleEnd next full cycle multiplied from unix epoch
        assertEq(
            savingsFrax.__rewardsCycleData().cycleEnd,
            ((block.timestamp + rewardsCycleLength) / rewardsCycleLength) * rewardsCycleLength,
            "setup: cycleEnd should be next full cycle multiplied from unix epoch"
        );

        /// GIVEN: lastSync is now
        assertEq(savingsFrax.__rewardsCycleData().lastSync, block.timestamp, "setup: lastSync should be now");

        /// GIVEN: rewardsForDistribution is 0
        assertEq(savingsFrax.__rewardsCycleData().rewardCycleAmount, 0, "setup: rewardsForDistribution should be 0");

        /// GIVEN: lastDistributionTime is now
        assertEq(savingsFrax.lastRewardsDistribution(), block.timestamp, "setup: lastDistributionTime should be now");

        /// GIVEN: rewardsCycleLength is 7 days
        assertEq(savingsFrax.REWARDS_CYCLE_LENGTH(), 7 days, "setup: rewardsCycleLength should be 7 days");
    }

    function test_DistributeRewardsNoRewards() public {
        /// GIVEN: move forward 1 day
        mineBlocksBySecond(1 days);

        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// WHEN: anyone calls distributeRewards()
        savingsFrax.distributeRewards();

        DeltaSavingsFraxStorageSnapshot memory _delta_savingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        /// THEN: lastDistributionTime should be current timestamp
        assertEq(
            _delta_savingsFraxStorageSnapshot.end.lastRewardsDistribution,
            block.timestamp,
            "THEN: lastDistributionTime should be current timestamp"
        );

        /// THEN: lastDistributionTime should have changed by 1 day
        assertEq(
            _delta_savingsFraxStorageSnapshot.delta.lastRewardsDistribution,
            1 days,
            "THEN: lastDistributionTime should have changed by 1 day"
        );

        /// THEN: totalSupply should not have changed
        assertEq(_delta_savingsFraxStorageSnapshot.delta.totalSupply, 0, "THEN: totalSupply should not have changed");

        /// THEN: storedTotalAssets should not have changed
        assertEq(
            _delta_savingsFraxStorageSnapshot.delta.storedTotalAssets,
            0,
            "THEN: storedTotalAssets should not have changed"
        );
    }

    function test_distributeRewardsInTheSameBlock() public {
        /// GIVEN: current timestamp is equal to lastRewardsDistribution

        /// GIVEN: current timestamp is equal to lastRewardsDistribution
        mineBlocksToTimestamp(savingsFrax.lastRewardsDistribution());

        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// WHEN: anyone calls distributeRewards()
        savingsFrax.distributeRewards();

        DeltaSavingsFraxStorageSnapshot memory _delta_savingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        /// THEN: lastDistributionTime should be current timestamp
        assertEq(
            _delta_savingsFraxStorageSnapshot.end.lastRewardsDistribution,
            block.timestamp,
            "THEN: lastDistributionTime should be current timestamp"
        );

        /// THEN: lastDistributionTime should have changed by 0
        assertEq(
            _delta_savingsFraxStorageSnapshot.delta.lastRewardsDistribution,
            0,
            "THEN: lastDistributionTime should have changed by 0"
        );

        /// THEN: totalSupply should not have changed
        assertEq(_delta_savingsFraxStorageSnapshot.delta.totalSupply, 0, "THEN: totalSupply should not have changed");

        /// THEN: storedTotalAssets should not have changed
        assertEq(
            _delta_savingsFraxStorageSnapshot.delta.storedTotalAssets,
            0,
            "THEN: storedTotalAssets should not have changed"
        );
    }
}
