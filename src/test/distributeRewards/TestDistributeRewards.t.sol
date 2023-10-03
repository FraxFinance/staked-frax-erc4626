// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../BaseTest.sol";

contract TestDistributeRewards is BaseTest {
    /// FEATURE: rewards distribution

    using StakedFraxStructHelper for *;
    using ArrayHelper for function()[];

    address bob;
    address alice;
    address donald;

    function setUp() public virtual {
        /// BACKGROUND: deploy the StakedFrax contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        defaultSetup();

        bob = labelAndDeal(address(1234), "bob");
        mintFraxTo(bob, 1000 ether);
        hoax(bob);
        fraxErc20.approve(stakedFraxAddress, type(uint256).max);

        alice = labelAndDeal(address(2345), "alice");
        mintFraxTo(alice, 1000 ether);
        hoax(alice);
        fraxErc20.approve(stakedFraxAddress, type(uint256).max);

        donald = labelAndDeal(address(3456), "donald");
        mintFraxTo(donald, 1000 ether);
        hoax(donald);
        fraxErc20.approve(stakedFraxAddress, type(uint256).max);
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

        StakedFraxStorageSnapshot memory _initial_stakedFraxStorageSnapshot = stakedFraxStorageSnapshot(stakedFrax);

        /// WHEN: anyone calls distributeRewards()
        stakedFrax.distributeRewards();

        DeltaStakedFraxStorageSnapshot memory _delta_stakedFraxStorageSnapshot = deltaStakedFraxStorageSnapshot(
            _initial_stakedFraxStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: lastDistributionTime should be current timestamp
        assertEq(
            _delta_stakedFraxStorageSnapshot.end.lastRewardsDistribution,
            block.timestamp,
            "THEN: lastDistributionTime should be current timestamp"
        );

        /// THEN: lastDistributionTime should have changed by 1 day
        assertEq(
            _delta_stakedFraxStorageSnapshot.delta.lastRewardsDistribution,
            1 days,
            "THEN: lastDistributionTime should have changed by 1 day"
        );

        /// THEN: totalSupply should not have changed
        assertEq(_delta_stakedFraxStorageSnapshot.delta.totalSupply, 0, "THEN: totalSupply should not have changed");

        /// THEN: storedTotalAssets should not have changed
        assertEq(
            _delta_stakedFraxStorageSnapshot.delta.storedTotalAssets,
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
        mineBlocksToTimestamp(stakedFrax.lastRewardsDistribution());

        //==============================================================================
        // Act
        //==============================================================================

        StakedFraxStorageSnapshot memory _initial_stakedFraxStorageSnapshot = stakedFraxStorageSnapshot(stakedFrax);

        /// WHEN: anyone calls distributeRewards()
        stakedFrax.distributeRewards();

        DeltaStakedFraxStorageSnapshot memory _delta_stakedFraxStorageSnapshot = deltaStakedFraxStorageSnapshot(
            _initial_stakedFraxStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: lastDistributionTime should be current timestamp
        assertEq(
            _delta_stakedFraxStorageSnapshot.end.lastRewardsDistribution,
            block.timestamp,
            "THEN: lastDistributionTime should be current timestamp"
        );

        /// THEN: lastDistributionTime should have changed by 0
        assertEq(
            _delta_stakedFraxStorageSnapshot.delta.lastRewardsDistribution,
            0,
            "THEN: lastDistributionTime should have changed by 0"
        );

        /// THEN: totalSupply should not have changed
        assertEq(_delta_stakedFraxStorageSnapshot.delta.totalSupply, 0, "THEN: totalSupply should not have changed");

        /// THEN: storedTotalAssets should not have changed
        assertEq(
            _delta_stakedFraxStorageSnapshot.delta.storedTotalAssets,
            0,
            "THEN: storedTotalAssets should not have changed"
        );
    }
}
