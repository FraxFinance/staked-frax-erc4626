// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../BaseTest.sol";
import {
    SavingsFraxFunctions
} from "../setMaxDistributionPerSecondPerAsset/TestSetMaxDistributionPerSecondPerAsset.t.sol";

contract TestMintAndDeposit is BaseTest, SavingsFraxFunctions {
    using SavingsFraxStructHelper for *;

    address bob;
    address alice;
    address donald;

    address joe;

    function setUp() public {
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

    function test_CanDepositNoRewards() public {
        /// SCENARIO: No rewards distribution, A user deposits 1000 FRAX and should have 50% of the shares

        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// WHEN: bob deposits 1000 FRAX
        startHoax(bob);
        savingsFrax.deposit(1000 ether, bob);

        DeltaSavingsFraxStorageSnapshot memory _delta_savingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        /// THEN: The user should have 1000 shares
        assertEq(savingsFrax.balanceOf(bob), 1000 ether, "THEN: The user should have 2000 shares");

        /// THEN: The totalSupply should have increased by 1000 shares
        assertEq(
            _delta_savingsFraxStorageSnapshot.delta.totalSupply,
            1000 ether,
            "THEN: THe totalSupply should have increased by 1000 shares"
        );

        /// THEN: The totalSupply should be 2000 shares
        assertEq(
            _delta_savingsFraxStorageSnapshot.end.totalSupply,
            2000 ether,
            "THEN: The totalSupply should be 2000 shares"
        );

        /// THEN: The storedTotalAssets should have increased by 1000 FRAX
        assertEq(
            _delta_savingsFraxStorageSnapshot.delta.storedTotalAssets,
            1000 ether,
            "THEN: The storedTotalAssets should have increased by 1000 FRAX"
        );

        /// THEN: storedTotalAssets should be 2000 FRAX
        assertEq(
            _delta_savingsFraxStorageSnapshot.end.storedTotalAssets,
            2000 ether,
            "THEN: storedTotalAssets should be 2000 FRAX"
        );
    }

    function test_CanDepositAndMintWithRewardsCappedRewards() public {
        /// SCENARIO: A user deposits 1000 FRAX and should have 50% of the shares, 1000 FRAX is distributed as rewards, uncapped

        uint256 _maxDistributionPerSecondPerAsset = 3_033_347_948;
        uint256 _syncDuration = 400_000;
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        uint256 _rewards = 600 ether;

        SavingsFraxStorageSnapshot memory _initial_savingsFraxSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// GIVEN: maxDistributionPerSecondPerAsset is at 3_033_347_948 per second per 1e18 asset (roughly 10% APY)
        _savingsFrax_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        mineBlocksToTimestamp(savingsFrax.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        mintFraxTo(savingsFraxAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        savingsFrax.syncRewardsAndDistribution();

        /// GIVEN: We wait 100_000 seconds
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        DeltaSavingsFraxStorageSnapshot
            memory _second_deltaSavingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
                _initial_savingsFraxSnapshot
            );

        // Cache setup for later use
        uint256 _endOfArrangePhase = vm.snapshot();

        //==============================================================================
        // Deposit Test
        //==============================================================================

        /// WHEN: A user deposits 1000 FRAX
        hoax(bob);
        savingsFrax.deposit(1000 ether, bob);

        DeltaSavingsFraxStorageSnapshot memory _third_deltaSavingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _second_deltaSavingsFraxStorageSnapshot.start
        );

        uint256 _expectedRewards = (1000e18 * _maxDistributionPerSecondPerAsset * _timeSinceLastRewardsDistribution) /
            1e18;
        /// THEN: the storedTotalAssets should have increased by 150 frax for the rewards and 1000 frax for the deposit
        assertEq(
            _third_deltaSavingsFraxStorageSnapshot.delta.storedTotalAssets,
            1000 ether + _expectedRewards,
            "storedTotalAssets should have increased by _expectedFrax for the rewards and 1000 frax for the deposit"
        );

        // _expected = newAssets / sharePrice, sharePrice = assets / shares
        uint256 _expectedShares = (uint256(1000e18) * 1000e18) / (1000e18 + _expectedRewards);
        /// THEN: The user should have 1000e18 * 1000e18 / 1150e18 shares
        assertEq(
            savingsFrax.balanceOf(bob),
            _expectedShares,
            "THEN: The user should have 1000e18 * 1000e18 / (1000 + _expectedRewards) shares"
        );

        /// THEN: The totalSupply should have increased by _expectedShares
        assertEq(
            _third_deltaSavingsFraxStorageSnapshot.delta.totalSupply,
            _expectedShares,
            " THEN: The totalSupply should have increased by _expectedShares"
        );

        //==============================================================================
        // Mint Test
        //==============================================================================

        /// GIVEN: revert back to the end of the arrange phase
        vm.revertTo(_endOfArrangePhase);

        /// WHEN: A user mints 1000 FRAX
        // uint256 _expectedSharesToMint = savingsFrax.convertToShares(1000 ether);
        hoax(bob);
        savingsFrax.mint(1000 ether, bob);

        DeltaSavingsFraxStorageSnapshot
            memory _fourth_deltaSavingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
                _second_deltaSavingsFraxStorageSnapshot.start
            );
        uint256 _expectedSharePrice = (1000 ether + _expectedRewards) / 1000;
        uint256 _expectedAmountTransferred = (1000 ether * _expectedSharePrice) / 1e18;
        // Expected transfer amount = shares * sharePrice, sharePrice = 1150 / 1000.  => 1000 ether + _expectedRewards frax transferred
        /// THEN: the storedTotalAssets should have increased by 150 frax for the rewards and 1150 frax for the mint

        assertEq(
            _fourth_deltaSavingsFraxStorageSnapshot.delta.storedTotalAssets,
            _expectedAmountTransferred + _expectedRewards,
            "storedTotalAssets should have increased by _expectedRewards frax for the rewards and _expectedAmountTransferred frax for the mint"
        );

        /// THEN: the user should have 1000 shares
        assertEq(savingsFrax.balanceOf(bob), 1000 ether, "THEN: the user should have 1000 shares");

        /// THEN: The totalSupply should have increased by _expectedShares
        assertEq(
            _fourth_deltaSavingsFraxStorageSnapshot.delta.totalSupply,
            1000 ether,
            " THEN: The totalSupply should have increased by 1000"
        );
    }

    function test_CanDepositMintWithdrawRedeemWithRewardsNoCap() public {
        /// SCENARIO: A user deposits 1000 FRAX and should have 50% of the shares, 1000 FRAX is distributed as rewards, uncapped

        uint256 _maxDistributionPerSecondPerAsset = type(uint256).max;
        uint256 _syncDuration = 400_000;
        uint256 _timeSinceLastRewardsDistribution = 100_000;
        uint256 _rewards = 600 ether;

        SavingsFraxStorageSnapshot memory _initial_savingsFraxSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// GIVEN: maxDistributionPerSecondPerAsset is uncapped
        _savingsFrax_setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);

        /// GIVEN: timestamp is 400_000 seconds away from the end of the cycle
        mineBlocksToTimestamp(savingsFrax.__rewardsCycleData().cycleEnd + rewardsCycleLength - _syncDuration);

        /// GIVEN: 600 FRAX is transferred as rewards
        mintFraxTo(savingsFraxAddress, _rewards);

        /// GIVEN: syncAndDistributeRewards is called
        savingsFrax.syncRewardsAndDistribution();

        /// GIVEN: We wait 100_000 seconds
        mineBlocksBySecond(_timeSinceLastRewardsDistribution);

        DeltaSavingsFraxStorageSnapshot
            memory _second_deltaSavingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
                _initial_savingsFraxSnapshot
            );

        // Cache setup for later use
        uint256 _endOfArrangePhase = vm.snapshot();

        //==============================================================================
        // Mint Test
        //==============================================================================

        /// WHEN: A user mints 1000 FRAX
        // uint256 _expectedSharesToMint = savingsFrax.convertToShares(1000 ether);
        hoax(bob);
        savingsFrax.mint(1000 ether, bob);

        DeltaSavingsFraxStorageSnapshot
            memory _fourth_deltaSavingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
                _second_deltaSavingsFraxStorageSnapshot.start
            );
        // Expected transfer amount = shares * sharePrice, sharePrice = 1150 / 1000.  => 1150 frax transferred
        /// THEN: the storedTotalAssets should have increased by 150 frax for the rewards and 1150 frax for the mint
        assertEq(
            _fourth_deltaSavingsFraxStorageSnapshot.delta.storedTotalAssets,
            1300 ether,
            "storedTotalAssets should have increased by 150 frax for the rewards and 1000 frax for the mint"
        );

        /// THEN: the user should have 1000 shares
        assertEq(savingsFrax.balanceOf(bob), 1000 ether, "THEN: the user should have 1000 shares");

        //==============================================================================
        // Deposit Test
        //==============================================================================

        /// GIVEN: revert back to the end of the arrange phase
        vm.revertTo(_endOfArrangePhase);

        /// WHEN: A user deposits 1000 FRAX
        hoax(bob);
        savingsFrax.deposit(1000 ether, bob);

        DeltaSavingsFraxStorageSnapshot memory _third_deltaSavingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _second_deltaSavingsFraxStorageSnapshot.start
        );

        /// THEN: the storedTotalAssets should have increased by 150 frax for the rewards and 1000 frax for the deposit
        assertEq(
            _third_deltaSavingsFraxStorageSnapshot.delta.storedTotalAssets,
            1150 ether,
            "storedTotalAssets should have increased by 150 frax for the rewards and 1000 frax for the deposit"
        );

        // _expected = newAssets / sharePrice, sharePrice = assets / shares
        uint256 _expectedShares = (uint256(1000e18) * 1000e18) / 1150e18;
        /// THEN: The user should have 1000e18 * 1000e18 / 1150e18 shares
        assertEq(
            savingsFrax.balanceOf(bob),
            _expectedShares,
            "THEN: The user should have 1000e18 * 1000e18 / 1150e18 shares"
        );

        /// THEN: The totalSupply should have increased by _expectedShares
        assertEq(
            _third_deltaSavingsFraxStorageSnapshot.delta.totalSupply,
            _expectedShares,
            " THEN: The totalSupply should have increased by _expectedShares"
        );

        uint256 _endOfDepositsPhase;
    }
}
