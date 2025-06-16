// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "./BaseTestStakedFrxUSD2.sol";
import "../../contracts/StakedFrax.sol";
import { LinearRewardsQuasiErc4626 } from "src/contracts/LinearRewardsQuasiErc4626.sol";
import { StakedFrxUSD2 } from "src/contracts/StakedFrxUSD2.sol";

contract TestDeploymentSfrxUSD2 is BaseTestStakedFrxUSD2 {
    function setUp() public {
        defaultSetup();
    }

    function test_Deploy() public {
        // Inspect contract storage values
        // ============================================
        assertEq(
            postUpgradeStorageSnapshot.storedTotalAssets,
            sfrxUSD2.totalAssets(),
            "storedTotalAssets should equal totalAssets"
        );
        assertEq(calcedDeltaPostUpgradeStorageSnapshot.totalSupply, 0, "totalSupply should have remained the same #1");

        assertEq(
            postUpgradeStorageSnapshot.pricePerShareStored,
            ppsInfo[0],
            "pricePerShareStored should be the pre-upgrade pricePerShare"
        );
        assertEq(
            postUpgradeStorageSnapshot.pricePerShareIncPerSecond,
            ppsInfo[1],
            "pricePerShareIncPerSecond should have been set"
        );
        assertEq(postUpgradeStorageSnapshot.lastSync, block.timestamp, "lastSync should be now");

        // Inspect user values
        // ============================================
        assertEq(
            postUpgradeAliceSnapshot.stakedFrxUSD2.balanceOf,
            aliceStartSfrxUSD,
            "aliceStartSfrxUSD should not have changed"
        );

        // Sync. Should not change any values. If it does, it could be a PRB Math issue or something else
        // ============================================
        sfrxUSD2.sync();

        // Take snapshots and deltas after the sync
        postAfterUpgradeSyncStorageSnapshot = stakedFrxUSD2StorageSnapshot(sfrxUSD2);
        calcedDeltaAfterUpgradeSyncStorageSnapshot = calculateDeltaStakedFrxUSD2Storage(
            postUpgradeStorageSnapshot,
            postAfterUpgradeSyncStorageSnapshot
        );
        postAfterUpgradeSyncAliceSnapshot = userStorageSnapshot(alice, sfrxUSD2);
        calcedDeltaAfterUpgradeSyncAliceSnapshot = calculateDeltaUserStorageSnapshot(
            postUpgradeAliceSnapshot,
            postAfterUpgradeSyncAliceSnapshot
        );

        // Inspect the contract storage deltas after the sync
        // ============================================
        assertEq(
            calcedDeltaAfterUpgradeSyncStorageSnapshot.storedTotalAssets,
            0,
            "storedTotalAssets should have remained the same #2"
        );
        assertEq(
            calcedDeltaAfterUpgradeSyncStorageSnapshot.totalSupply,
            0,
            "totalSupply should have remained the same #2"
        );
        assertEq(
            calcedDeltaAfterUpgradeSyncStorageSnapshot.pricePerShareStored,
            0,
            "pricePerShareStored should have remained the same #2"
        );
        assertEq(
            calcedDeltaAfterUpgradeSyncStorageSnapshot.pricePerShareIncPerSecond,
            0,
            "pricePerShareIncPerSecond should have remained the same #2"
        );
        assertEq(calcedDeltaAfterUpgradeSyncStorageSnapshot.lastSync, 0, "lastSync should have remained the same #2");

        // Inspect the user deltas after the sync
        // ============================================
        assertEq(
            calcedDeltaAfterUpgradeSyncAliceSnapshot.stakedFrxUSD2.balanceOf,
            0,
            "Alice's sfrxUSD balance should have remained the same"
        );
        assertEq(
            calcedDeltaAfterUpgradeSyncAliceSnapshot.asset.balanceOf,
            0,
            "Alice's frxUSD balance should have remained the same"
        );
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            1000e18,
            0.0001e18,
            "Alice's sfrxUSD asset value should be close to 1000 frxUSD [test_Deploy]"
        );
    }
}
