// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../BaseTest.sol";

abstract contract SavingsFraxFunctions is BaseTest {
    function _savingsFrax_setMaxDistributionPerSecondPerAsset(uint256 _maxDistributionPerSecondPerAsset) internal {
        hoax(savingsFrax.timelockAddress());
        savingsFrax.setMaxDistributionPerSecondPerAsset(_maxDistributionPerSecondPerAsset);
    }
}

contract TestSetMaxDistributionPerSecondPerAsset is BaseTest, SavingsFraxFunctions {
    /// FEATURE: setMaxDistributionPerSecondPerAsset

    function setUp() public {
        /// BACKGROUND: deploy the SavingsFrax contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        defaultSetup();
    }

    function test_CannotCallIfNotTimelock() public {
        /// WHEN: non-timelock calls setMaxDistributionPerSecondPerAsset
        vm.expectRevert(
            abi.encodeWithSelector(
                Timelock2Step.AddressIsNotTimelock.selector,
                savingsFrax.timelockAddress(),
                address(this)
            )
        );
        savingsFrax.setMaxDistributionPerSecondPerAsset(1 ether);
        /// THEN: we expect a revert with the AddressIsNotTimelock error
    }

    function test_CannotSetAboveUint64() public {
        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// WHEN: timelock sets maxDistributionPerSecondPerAsset to uint64.max + 1
        _savingsFrax_setMaxDistributionPerSecondPerAsset(uint256(type(uint64).max) + 1);

        DeltaSavingsFraxStorageSnapshot memory _delta_savingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        /// THEN: values should be equal to uint64.max
        assertEq(
            _delta_savingsFraxStorageSnapshot.end.maxDistributionPerSecondPerAsset,
            type(uint64).max,
            "THEN: values should be equal to uint64.max"
        );
    }

    function test_CanSetMaxDistributionPerSecondPerAsset() public {
        SavingsFraxStorageSnapshot memory _initial_savingsFraxStorageSnapshot = savingsFraxStorageSnapshot(savingsFrax);

        /// WHEN: timelock sets maxDistributionPerSecondPerAsset to 1 ether
        _savingsFrax_setMaxDistributionPerSecondPerAsset(1 ether);

        DeltaSavingsFraxStorageSnapshot memory _delta_savingsFraxStorageSnapshot = deltaSavingsFraxStorageSnapshot(
            _initial_savingsFraxStorageSnapshot
        );

        /// THEN: maxDistributionPerSecondPerAsset should be 1 ether
        assertEq(
            _delta_savingsFraxStorageSnapshot.end.maxDistributionPerSecondPerAsset,
            1 ether,
            "THEN: maxDistributionPerSecondPerAsset should be 1 ether"
        );
    }
}
