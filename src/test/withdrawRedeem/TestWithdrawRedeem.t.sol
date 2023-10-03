// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../BaseTest.sol";
import {
    StakedFraxFunctions
} from "../setMaxDistributionPerSecondPerAsset/TestSetMaxDistributionPerSecondPerAsset.t.sol";
import { mintDepositFunctions } from "../mintDeposit/TestMintAndDeposit.t.sol";

abstract contract RedeemWithdrawFunctions is BaseTest {
    function _stakedFrax_redeem(uint256 _shares, address _recipient) internal {
        hoax(_recipient);
        stakedFrax.redeem(_shares, _recipient, _recipient);
    }

    function _stakedFrax_withdraw(uint256 _assets, address _recipient) internal {
        hoax(_recipient);
        stakedFrax.withdraw(_assets, _recipient, _recipient);
    }
}

contract TestRedeemAndWithdraw is BaseTest, StakedFraxFunctions, mintDepositFunctions, RedeemWithdrawFunctions {
    /// FEATURE: redeem and withdraw

    using StakedFraxStructHelper for *;

    address bob;
    address alice;
    address donald;

    address joe;

    function setUp() public {
        /// BACKGROUND: deploy the StakedFrax contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        defaultSetup();

        bob = labelAndDeal(address(1234), "bob");
        mintFraxTo(bob, 5000 ether);
        hoax(bob);
        fraxErc20.approve(stakedFraxAddress, type(uint256).max);

        alice = labelAndDeal(address(2345), "alice");
        mintFraxTo(alice, 5000 ether);
        hoax(alice);
        fraxErc20.approve(stakedFraxAddress, type(uint256).max);

        donald = labelAndDeal(address(3456), "donald");
        mintFraxTo(donald, 5000 ether);
        hoax(donald);
        fraxErc20.approve(stakedFraxAddress, type(uint256).max);

        joe = labelAndDeal(address(4567), "joe");
        mintFraxTo(joe, 5000 ether);
        hoax(joe);
        fraxErc20.approve(stakedFraxAddress, type(uint256).max);
    }

    function test_RedeemAllWithUnCappedRewards() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: totalSupply is 1000
        assertEq(stakedFrax.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// GIVEN: storedTotalAssets is 1000
        assertEq(stakedFrax.storedTotalAssets(), 1000 ether, "setup: storedTotalAssets should be 1000");

        /// GIVEN: maxDistributionPerSecondPerAsset is uncapped
        uint256 _maxDistributionPerSecondPerAsset = type(uint256).max;
        _stakedFrax_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        uint256 _syncDuration = 400_000;
        mineBlocksToTimestamp(stakedFrax.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        uint256 _rewards = 600 ether;
        mintFraxTo(stakedFraxAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        stakedFrax.syncRewardsAndDistribution();

        /// GIVEN: bob deposits 1000 FRAX
        _stakedFrax_deposit(1000 ether, bob);

        /// GIVEN: We wait 100_000 seconds
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        //==============================================================================
        // Act
        //==============================================================================

        StakedFraxStorageSnapshot memory _initial_stakedFraxStorageSnapshot = stakedFraxStorageSnapshot(stakedFrax);

        UserStorageSnapshot memory _initial_bobStorageSnapshot = userStorageSnapshot(bob, stakedFrax);

        /// WHEN: bob redeems all of his FRAX
        uint256 _shares = stakedFrax.balanceOf(bob);
        _stakedFrax_redeem(_shares, bob);

        DeltaStakedFraxStorageSnapshot memory _delta_stakedFraxStorageSnapshot = deltaStakedFraxStorageSnapshot(
            _initial_stakedFraxStorageSnapshot
        );

        DeltaUserStorageSnapshot memory _delta_bobStorageSnapshot = deltaUserStorageSnapshot(
            _initial_bobStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "THEN: totalSupply should decrease by _shares",
            a: _delta_stakedFraxStorageSnapshot.delta.totalSupply,
            b: _shares
        });
        assertLt({
            err: "THEN: totalSupply should decrease",
            a: _delta_stakedFraxStorageSnapshot.end.totalSupply,
            b: _delta_stakedFraxStorageSnapshot.start.totalSupply
        });

        uint256 _expectedWithdrawAmount = 1075e18 - 150e18;
        assertEq({
            err: "THEN: totalStored assets should change by +150 for rewards and -1125 for redeem",
            a: _delta_stakedFraxStorageSnapshot.delta.storedTotalAssets,
            b: _expectedWithdrawAmount
        });

        assertEq({
            err: "THEN: bob's balance should be 0",
            a: _delta_bobStorageSnapshot.end.stakedFrax.balanceOf,
            b: 0
        });
        assertEq({
            err: "THEN: bob's frax balance should have changed by 1075 (1000 + 75 rewards)",
            a: _delta_bobStorageSnapshot.delta.asset.balanceOf,
            b: 1075 ether
        });
    }

    function test_WithdrawWithUnCappedRewards() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: totalSupply is 1000
        assertEq(stakedFrax.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// GIVEN: storedTotalAssets is 1000
        assertEq(stakedFrax.storedTotalAssets(), 1000 ether, "setup: storedTotalAssets should be 1000");

        /// GIVEN: maxDistributionPerSecondPerAsset is uncapped
        uint256 _maxDistributionPerSecondPerAsset = type(uint256).max;
        _stakedFrax_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        uint256 _syncDuration = 400_000;
        mineBlocksToTimestamp(stakedFrax.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        uint256 _rewards = 600 ether;
        mintFraxTo(stakedFraxAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        stakedFrax.syncRewardsAndDistribution();

        /// GIVEN: bob deposits 1000 FRAX
        _stakedFrax_deposit(1000 ether, bob);

        /// GIVEN: We wait 100_000 seconds
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        //==============================================================================
        // Act
        //==============================================================================

        StakedFraxStorageSnapshot memory _initial_stakedFraxStorageSnapshot = stakedFraxStorageSnapshot(stakedFrax);

        UserStorageSnapshot memory _initial_bobStorageSnapshot = userStorageSnapshot(bob, stakedFrax);

        /// WHEN: bob withdraws 1000 frax
        _stakedFrax_withdraw(1000 ether, bob);

        DeltaStakedFraxStorageSnapshot memory _delta_stakedFraxStorageSnapshot = deltaStakedFraxStorageSnapshot(
            _initial_stakedFraxStorageSnapshot
        );

        DeltaUserStorageSnapshot memory _delta_bobStorageSnapshot = deltaUserStorageSnapshot(
            _initial_bobStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        uint256 _expectedShares = (uint256(2000e18) * 1000e18) / 2150e18;
        assertApproxEqAbs({
            err: "/// THEN: totalSupply should decrease by totalSupply / totalAssets * 1000",
            a: _delta_stakedFraxStorageSnapshot.delta.totalSupply,
            b: _expectedShares,
            maxDelta: 1
        });
        assertLt({
            err: "/// THEN: totalSupply should decrease",
            a: _delta_stakedFraxStorageSnapshot.end.totalSupply,
            b: _delta_stakedFraxStorageSnapshot.start.totalSupply
        });
        assertEq({
            err: "/// THEN: totalStored assets should change by -1000 +150 for rewards",
            a: _delta_stakedFraxStorageSnapshot.delta.storedTotalAssets,
            b: 850e18
        });
        assertApproxEqAbs({
            err: "/// THEN: bob's balance should be 1000 - _expectedShares",
            a: _delta_bobStorageSnapshot.end.stakedFrax.balanceOf,
            b: 1000e18 - _expectedShares,
            maxDelta: 1
        });
        assertApproxEqAbs({
            err: "/// THEN: bob's staked frax balance should have changed by _expectedShares",
            a: _delta_bobStorageSnapshot.delta.stakedFrax.balanceOf,
            b: _expectedShares,
            maxDelta: 1
        });
        assertEq({
            err: "/// THEN: bob's frax balance should have changed by 1000",
            a: _delta_bobStorageSnapshot.delta.asset.balanceOf,
            b: 1000 ether
        });
    }
}
