// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../BaseTest.sol";
import {
    SavingsFraxFunctions
} from "../setMaxDistributionPerSecondPerAsset/TestSetMaxDistributionPerSecondPerAsset.t.sol";
import { mintDepositFunctions } from "../mintDeposit/TestMintAndDeposit.t.sol";

abstract contract RedeemWithdrawFunctions is BaseTest {
    function _savingsFrax_redeem(uint256 _shares, address _recipient) internal {
        hoax(_recipient);
        savingsFrax.redeem(_shares, _recipient, _recipient);
    }

    function _savingsFrax_withdraw(uint256 _assets, address _recipient) internal {
        hoax(_recipient);
        savingsFrax.withdraw(_assets, _recipient, _recipient);
    }
}

contract TestRedeemAndWithdraw is BaseTest, SavingsFraxFunctions, mintDepositFunctions, RedeemWithdrawFunctions {
    /// FEATURE: redeem and withdraw

    using SavingsFraxStructHelper for *;

    address bob;
    address alice;
    address donald;

    address joe;

    function setUp() public {
        /// BACKGROUND: deploy the SavingsFrax contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        defaultSetup();

        bob = labelAndDeal(address(1234), "bob");
        mintFraxTo(bob, 5000 ether);
        hoax(bob);
        fraxErc20.approve(savingsFraxAddress, type(uint256).max);

        alice = labelAndDeal(address(2345), "alice");
        mintFraxTo(alice, 5000 ether);
        hoax(alice);
        fraxErc20.approve(savingsFraxAddress, type(uint256).max);

        donald = labelAndDeal(address(3456), "donald");
        mintFraxTo(donald, 5000 ether);
        hoax(donald);
        fraxErc20.approve(savingsFraxAddress, type(uint256).max);

        joe = labelAndDeal(address(4567), "joe");
        mintFraxTo(joe, 5000 ether);
        hoax(joe);
        fraxErc20.approve(savingsFraxAddress, type(uint256).max);
    }

    function test_RedeemAllWithUnCappedRewards() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: totalSupply is 1000
        assertEq(savingsFrax.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// GIVEN: storedTotalAssets is 1000
        assertEq(savingsFrax.storedTotalAssets(), 1000 ether, "setup: storedTotalAssets should be 1000");

        /// GIVEN: maxDistributionPerSecondPerAsset is uncapped
        uint256 _maxDistributionPerSecondPerAsset = type(uint256).max;
        _savingsFrax_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        uint256 _syncDuration = 400_000;
        mineBlocksToTimestamp(savingsFrax.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        uint256 _rewards = 600 ether;
        mintFraxTo(savingsFraxAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        savingsFrax.syncRewardsAndDistribution();

        /// GIVEN: bob deposits 1000 FRAX
        _savingsFrax_deposit(1000 ether, bob);

        /// GIVEN: We wait 100_000 seconds
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        //==============================================================================
        // Act
        //==============================================================================

        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        UserStorageSnapshot memory _initial_bobStorageSnapshot = userStorageSnapshot(bob, savingsFrax);

        /// WHEN: bob redeems all of his FRAX
        uint256 _shares = savingsFrax.balanceOf(bob);
        _savingsFrax_redeem(_shares, bob);

        DeltaSavingsFraxStorageSnapshot memory _delta_savingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        DeltaUserStorageSnapshot memory _delta_bobStorageSnapshot = deltaUserStorageSnapshot(
            _initial_bobStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: totalSupply should decrease by _shares
        assertEq(
            _delta_savingsFraxStorageSnapshot.delta.totalSupply,
            _shares,
            "THEN: totalSupply should decrease by _shares"
        );
        assertLt(
            _delta_savingsFraxStorageSnapshot.end.totalSupply,
            _delta_savingsFraxStorageSnapshot.start.totalSupply,
            "THEN: totalSupply should decrease"
        );

        uint256 _expectedWithdrawAmount = 1075e18 - 150e18;
        /// THEN totalStored assets should change by +150 for rewards and -1125 for redeem
        assertEq(
            _delta_savingsFraxStorageSnapshot.delta.storedTotalAssets,
            _expectedWithdrawAmount,
            "THEN totalStored assets should change by +150 for rewards and -1000 for redeem"
        );

        /// THEN: bob's balance should be 0
        assertEq(_delta_bobStorageSnapshot.end.savingsFrax.balanceOf, 0, "THEN: bob's balance should be 0");

        /// Then bob's frax balance should have changed by 1125
        assertEq(
            _delta_bobStorageSnapshot.delta.asset.balanceOf,
            1075 ether,
            "THEN: bob's frax balance should have changed by 1125"
        );
    }

    function test_WithdrawWithUnCappedRewards() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: totalSupply is 1000
        assertEq(savingsFrax.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// GIVEN: storedTotalAssets is 1000
        assertEq(savingsFrax.storedTotalAssets(), 1000 ether, "setup: storedTotalAssets should be 1000");

        /// GIVEN: maxDistributionPerSecondPerAsset is uncapped
        uint256 _maxDistributionPerSecondPerAsset = type(uint256).max;
        _savingsFrax_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        uint256 _syncDuration = 400_000;
        mineBlocksToTimestamp(savingsFrax.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        uint256 _rewards = 600 ether;
        mintFraxTo(savingsFraxAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        savingsFrax.syncRewardsAndDistribution();

        /// GIVEN: bob deposits 1000 FRAX
        _savingsFrax_deposit(1000 ether, bob);

        /// GIVEN: We wait 100_000 seconds
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        //==============================================================================
        // Act
        //==============================================================================

        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        UserStorageSnapshot memory _initial_bobStorageSnapshot = userStorageSnapshot(bob, savingsFrax);

        /// WHEN: bob withdraws 1000 frax
        _savingsFrax_withdraw(1000 ether, bob);

        DeltaSavingsFraxStorageSnapshot memory _delta_savingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        DeltaUserStorageSnapshot memory _delta_bobStorageSnapshot = deltaUserStorageSnapshot(
            _initial_bobStorageSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: totalSupply should decrease by totalSupply / totalAssets * 1000
        uint256 _expectedShares = (uint256(1000e18) * 1000e18) / 2150e18;
        assertEq(
            _delta_savingsFraxStorageSnapshot.delta.totalSupply,
            _expectedShares,
            "THEN: totalSupply should decrease by totalSupply / totalAssets * 1000"
        );
        assertLt(
            _delta_savingsFraxStorageSnapshot.end.totalSupply,
            _delta_savingsFraxStorageSnapshot.start.totalSupply,
            "THEN: totalSupply should decrease"
        );

        /// THEN: totalStored assets should change by -1000 +150 for rewards
        assertEq(
            _delta_savingsFraxStorageSnapshot.delta.storedTotalAssets,
            850e18,
            "THEN: totalStored assets should change by -1000 +150 for rewards"
        );

        /// THEN: bob's balance should be 1000 - _expectedShares
        assertEq(
            _delta_bobStorageSnapshot.end.savingsFrax.balanceOf,
            1000e18 - _expectedShares,
            "THEN: bob's balance should be 1000 - _expectedShares"
        );

        /// THEN: bob's savings frax balance should have changed by _expectedShares
        assertEq(
            _delta_bobStorageSnapshot.delta.savingsFrax.balanceOf,
            _expectedShares,
            "THEN: bob's frax balance should have changed by _expectedShares"
        );

        /// THEN: bob's frax balance should have changed by 1000
        assertEq(
            _delta_bobStorageSnapshot.delta.asset.balanceOf,
            1000 ether,
            "THEN: bob's frax balance should have changed by 1000"
        );
    }
}
