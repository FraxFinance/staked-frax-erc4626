// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../BaseTest.sol";

contract TestSyncRewards is BaseTest {
    /// FEATURE: syncRewards

    using SavingsFraxStructHelper for *;

    address bob;
    address alice;
    address donald;

    function setUp() public {
        /// BACKGROUND: deploy the SavingsFrax contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
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

    function test_SyncRewardsData() public {
        //==============================================================================
        // Arrange
        //==============================================================================
        /// GIVEN: we are 1 day past the end of the old cycle
        MineBlocksResult memory _minBlocksResult = mineBlocksToTimestamp(
            savingsFrax.__rewardsCycleData().cycleEnd + 1 days
        );

        /// GIVEN: 50 Frax is transferred to the savingsFrax contract
        mintFraxTo(savingsFraxAddress, 50 ether);

        //==============================================================================
        // Act
        //==============================================================================

        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// WHEN: anyone calls syncRewardsAndDistribution()
        savingsFrax.syncRewardsAndDistribution();

        DeltaSavingsFraxStorageSnapshot memory _first_deltaSavingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: lastSync should be current timestamp
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.end.rewardsCycleData.lastSync,
            block.timestamp,
            "THEN: lastSync should be current timestamp"
        );

        /// THEN: lastSync should have changed by the time elapsed since deploy
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.delta.rewardsCycleData.lastSync,
            _minBlocksResult.timeElapsed,
            "THEN: lastSync should have changed by the cycleLength"
        );

        /// THEN: rewardCycleAmount should be 50 frax
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.end.rewardsCycleData.rewardCycleAmount,
            50 ether,
            "THEN: rewardsForDistribution should be 50"
        );

        /// THEN: rewardCycleAmount should have changed by 50 frax
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.delta.rewardsCycleData.rewardCycleAmount,
            50 ether,
            "THEN: rewardsForDistribution should have changed by 50"
        );

        /// THEN: cycle end should be initial cycle end + cycle length
        uint256 _initialCycleEnd = _first_deltaSavingsFraxStorageSnapshot.start.rewardsCycleData.cycleEnd;
        uint256 _expectedCycleEnd = _initialCycleEnd + rewardsCycleLength;
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.end.rewardsCycleData.cycleEnd,
            _expectedCycleEnd,
            "THEN: cycle end should be initial cycle end + cycle length"
        );

        /// THEN: cycleEnd should have changed by an amount equal to cycle length
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.delta.rewardsCycleData.cycleEnd,
            rewardsCycleLength,
            "THEN: cycleEnd should have changed by an amount equal to cycle length"
        );
    }

    function test_SyncRewardsAtEndOfCycle() public {
        //==============================================================================
        // Arrange
        //==============================================================================
        /// GIVEN: we are 1 day past the end of the old cycle and we sync rewards
        mineBlocksToTimestamp(savingsFrax.__rewardsCycleData().cycleEnd + 1 days);
        savingsFrax.syncRewardsAndDistribution();

        /// GIVEN: The current timestamp is rewardsCycleLength - 100 seconds past cycle end (i.e. 100 seconds before the NEXT cycle ends and sync has not been called)
        MineBlocksResult memory _mineBlocksResult = mineBlocksToTimestamp(
            savingsFrax.__rewardsCycleData().cycleEnd + rewardsCycleLength - 100
        );

        /// GIVEN: 50 Frax is transferred to the savingsFrax contract
        mintFraxTo(savingsFraxAddress, 50 ether);

        //==============================================================================
        // Act
        //==============================================================================

        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// WHEN: anyone calls syncRewardsAndDistribution()
        savingsFrax.syncRewardsAndDistribution();

        DeltaSavingsFraxStorageSnapshot memory _first_deltaSavingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: lastSync should be current timestamp
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.end.rewardsCycleData.lastSync,
            block.timestamp,
            "THEN: lastSync should be current timestamp"
        );

        /// THEN: lastSync should have changed by the time elapsed since the prior sync
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.delta.rewardsCycleData.lastSync,
            _mineBlocksResult.timeElapsed,
            "THEN: lastSync should have changed by the cycleLength"
        );

        /// THEN: rewardCycleAmount should be 50
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.end.rewardsCycleData.rewardCycleAmount,
            50 ether,
            "THEN: rewardsForDistribution should be 50"
        );

        /// THEN: rewardsCycleAmount should have changed by 50
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.delta.rewardsCycleData.rewardCycleAmount,
            50 ether,
            "THEN: rewardsForDistribution should have changed by 50"
        );

        /// THEN: cycle end should be initial cycle end plus 2 cycle lengths to prevent big jumps in distributions
        uint256 _initialCycleEnd = _first_deltaSavingsFraxStorageSnapshot.start.rewardsCycleData.cycleEnd;
        uint256 _expectedCycleEnd = _initialCycleEnd + 2 * rewardsCycleLength;
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.end.rewardsCycleData.cycleEnd,
            _expectedCycleEnd,
            "THEN: cycle end should be initial cycle end + 2 * cycle length"
        );

        /// THEN: cycleEnd should have changed by an amount equal to 2 cycle lengths
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.delta.rewardsCycleData.cycleEnd,
            2 * rewardsCycleLength,
            "THEN: cycleEnd should have changed by an amount equal to 2 cycle lengths"
        );
    }

    function test_syncRewardsBeforeEndOfCycle() public {
        /// SCENARIO: A sync happens before the end of the cycle

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: we are 1 day past the end of the old cycle and we sync rewards
        mineBlocksToTimestamp(savingsFrax.__rewardsCycleData().cycleEnd + 1 days);
        savingsFrax.syncRewardsAndDistribution();

        /// GIVEN: The current timestamp is rewardsCycleLength - 1000.  i.e. cycle has not ended
        mineBlocksToTimestamp(savingsFrax.__rewardsCycleData().cycleEnd - 1000);

        //==============================================================================
        // Act
        //==============================================================================

        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// WHEN: anyone calls syncRewardsAndDistribution()
        savingsFrax.syncRewardsAndDistribution();

        DeltaSavingsFraxStorageSnapshot memory _first_deltaSavingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: lastSync should be the same as the initial lastSync
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.end.rewardsCycleData.lastSync,
            _first_deltaSavingsFraxStorageSnapshot.start.rewardsCycleData.lastSync,
            "THEN: lastSync should be the same as the initial lastSync"
        );

        /// THEN: lastSync should have changed by 0
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.delta.rewardsCycleData.lastSync,
            0,
            "THEN: lastSync should have changed by 0"
        );

        /// THEN: rewardCycleAmount should be 0
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.end.rewardsCycleData.rewardCycleAmount,
            0,
            "THEN: rewardsForDistribution should be 0"
        );

        /// THEN: cycle end should be the same as the initial cycle end
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.end.rewardsCycleData.cycleEnd,
            _first_deltaSavingsFraxStorageSnapshot.start.rewardsCycleData.cycleEnd,
            "THEN: cycle end should be the same as the initial cycle end"
        );

        /// THEN: cycleEnd should have changed by 0
        assertEq(
            _first_deltaSavingsFraxStorageSnapshot.delta.rewardsCycleData.cycleEnd,
            0,
            "THEN: cycleEnd should have changed by 0"
        );
    }
}
