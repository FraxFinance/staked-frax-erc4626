// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../BaseTest.sol";

contract TestDistributeRewards is BaseTest {
    /// FEATURE: rewards distribution

    using SavingsFraxStructHelper for *;
    using ArrayHelper for function()[];

    address bob;
    address alice;
    address donald;

    function setUp() public virtual {
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

    function test_DistributeRewardsNoRewards() public {
        /// SCENARIO: distributeRewards() is called when there are no rewards

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: move forward 1 day
        mineBlocksBySecond(1 days);

        //==============================================================================
        // Act
        //==============================================================================

        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// WHEN: anyone calls distributeRewards()
        savingsFrax.distributeRewards();

        DeltaSavingsFraxStorageSnapshot memory _delta_savingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

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
        /// SCENARIO: distributeRewards() is called twice in the same block

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: current timestamp is equal to lastRewardsDistribution
        mineBlocksToTimestamp(savingsFrax.lastRewardsDistribution());

        //==============================================================================
        // Act
        //==============================================================================

        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// WHEN: anyone calls distributeRewards()
        savingsFrax.distributeRewards();

        DeltaSavingsFraxStorageSnapshot memory _delta_savingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

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
