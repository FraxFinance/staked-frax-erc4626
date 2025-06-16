// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "./BaseTestStakedFrxUSD2.sol";
import "../../contracts/StakedFrax.sol";
import { DecimalStringHelper } from "src/test/helpers/DecimalStringHelper.sol";
import { LinearRewardsQuasiErc4626 } from "src/contracts/LinearRewardsQuasiErc4626.sol";
import { StakedFrxUSD2 } from "src/contracts/StakedFrxUSD2.sol";
import { Timelock2Step } from "frax-std/access-control/v2/Timelock2Step.sol";
import { mul, div, ln } from "@prb/math/src/ud60x18/Math.sol";
import { convert } from "@prb/math/src/ud60x18/Conversions.sol";
import { UD60x18 } from "@prb/math/src/ud60x18/ValueType.sol";

contract TestPPSManipulations is BaseTestStakedFrxUSD2 {
    using DecimalStringHelper for uint256;

    // For testing
    uint256 frxUSDBefore;
    uint256 sfrxUSDBefore;
    uint256 aliceShareBalBefore;
    uint256 aliceAssetBalBefore;
    uint256 aliceShareBalAfter;
    uint256 aliceAssetBalAfter;

    function setUp() public {
        defaultSetup();

        // Alice should start with 1000 frxUSD worth of sfrxUSD
        // ----------------------------------------
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            1000e18,
            0.0001e18,
            "Alice's sfrxUSD asset value should be close to 1000 frxUSD [TestPPSManipulations setUp]"
        );

        // Timelock makes itself a minter
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.addMinter(Constants.Mainnet.FRAX_ERC20_OWNER);
    }

    // ===================================================
    // BASIC TESTS
    // ===================================================

    function test_PreviewVsActualPPS() public {
        // Preview the PPS 1 year from now
        uint256 _initialPPS = sfrxUSD2.previewPricePerShare();
        uint256 _estFuturePPS = sfrxUSD2.previewPricePerShareFuture(block.timestamp + ONE_YEAR);

        // Sync once per month for 12 months
        for (uint256 i = 0; i < 12; i++) {
            // Warp 1 month
            _warpToAndRollOne(block.timestamp + ONE_MONTH);

            // Sync
            sfrxUSD2.sync();
        }

        // Actual PPS should be 5% higher than the initial one
        assertApproxEqRel(
            sfrxUSD2.pricePerShare(),
            (_initialPPS * 1.05e18) / 1e18,
            0.0005e18,
            "Actual PPS should be 5% higher than the initial one [test_PreviewVsActualPPS]"
        );

        // Actual PPS should match that estimated 12 months ago
        assertApproxEqRel(
            sfrxUSD2.pricePerShare(),
            _estFuturePPS,
            0.0005e18,
            "Actual PPS should match that estimated 12 months ago [test_PreviewVsActualPPS]"
        );

        // Alice should have earned 5%
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            1050e18,
            0.0005e18,
            "Alice's sfrxUSD asset value should be close to 1050 frxUSD [test_PreviewVsActualPPS]"
        );
    }

    function test_PreviewVsActualTotalAssets() public {
        // Preview the totalAssets 1 year from now
        uint256 _initialTA = sfrxUSD2.previewTotalAssets();
        uint256 _estFutureTA = sfrxUSD2.previewTotalAssetsFuture(block.timestamp + ONE_YEAR);

        // Sync once per month for 12 months
        for (uint256 i = 0; i < 12; i++) {
            // Warp 1 month
            _warpToAndRollOne(block.timestamp + ONE_MONTH);

            // Sync
            sfrxUSD2.sync();
        }

        // Actual TA should be 5% higher than the initial one
        assertApproxEqRel(
            sfrxUSD2.totalAssets(),
            (_initialTA * 1.05e18) / 1e18,
            0.0005e18,
            "Actual TA should be 5% higher than the initial one [test_PreviewVsActualTotalAssets]"
        );

        // Actual TA should match that estimated 12 months ago
        assertApproxEqRel(
            sfrxUSD2.totalAssets(),
            _estFutureTA,
            0.0005e18,
            "Actual TA should match that estimated 12 months ago [test_PreviewVsActualTotalAssets]"
        );
    }

    function test_SetParams() public {
        // Owner should be able to do privileged setter functions
        // ------------------------------------------------
        // Become the owner
        startHoax(Constants.Mainnet.FRAX_ERC20_OWNER);

        // setAllPricingParams
        sfrxUSD2.setAllPricingParams(1e18, 1e6, block.timestamp);

        // Try to setAllPricingParams with future lastSync time (should fail)
        vm.expectRevert(StakedFrxUSD2.MustNotBeInTheFuture.selector);
        sfrxUSD2.setAllPricingParams(1e18, 1e6, block.timestamp + 1);

        // setPricePerShareIncPerSecond
        sfrxUSD2.setPricePerShareIncPerSecond(1e6);

        // setPricePerShareStored
        sfrxUSD2.setPricePerShareStored(1e18);

        // End Alice hoax
        vm.stopPrank();

        // Alice should not be able to do any privileged setter functions
        // ------------------------------------------------
        // Become Alice
        startHoax(alice);

        // Alice tries to setAllPricingParams (should fail)
        vm.expectRevert(
            abi.encodeWithSelector(Timelock2Step.AddressIsNotTimelock.selector, sfrxUSD2.timelockAddress(), alice)
        );
        sfrxUSD2.setAllPricingParams(0, 0, 0);

        // Alice tries to setPricePerShareIncPerSecond (should fail)
        vm.expectRevert(
            abi.encodeWithSelector(Timelock2Step.AddressIsNotTimelock.selector, sfrxUSD2.timelockAddress(), alice)
        );
        sfrxUSD2.setPricePerShareIncPerSecond(0);

        // Alice tries to setPricePerShareStored (should fail)
        vm.expectRevert(
            abi.encodeWithSelector(Timelock2Step.AddressIsNotTimelock.selector, sfrxUSD2.timelockAddress(), alice)
        );
        sfrxUSD2.setPricePerShareStored(0);

        // End Alice hoax
        vm.stopPrank();
    }

    function test_1YrTtl_Simple() public {
        // Nobody else deposits
        // No PPS changes
        // ======================================

        // Warp one year ahead
        _warpToAndRollOne(block.timestamp + ONE_YEAR);

        // Alice should have earned 5%
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            1050e18,
            0.0005e18,
            "Alice's sfrxUSD asset value should be close to 1050 frxUSD [test_1YrTtl_Simple]"
        );
    }

    function test_1YrTtl_BackToTheFuture() public {
        // Nobody else deposits
        // No direct PPS changes
        // lastSync is reset back a year, after elapsing a year. Alice should earn 5% a second time
        // ======================================

        // Note Alice's sfrxUSD asset value initially
        uint256 aliceAssetBalInitial = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Warp one year ahead
        _warpToAndRollOne(block.timestamp + ONE_YEAR);

        // Note Alice's sfrxUSD asset value after the warp, before the setLastSync
        uint256 aliceAssetBalAfter1stWarp = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Sync to "save" pricePerShareStored and lastSync
        sfrxUSD2.sync();

        // Alice should have earned 5%
        assertApproxEqRel(
            aliceAssetBalAfter1stWarp,
            (aliceAssetBalInitial * 1.05e18) / 1e18,
            0.0005e18,
            "Alice's sfrxUSD asset value should have increased 5% [test_1YrTtl_BackToTheFuture]"
        );

        // Set lastSync back a year
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.setAllPricingParams(
            sfrxUSD2.pricePerShare(),
            sfrxUSD2.pricePerShareIncPerSecond(),
            block.timestamp - ONE_YEAR
        );
        vm.stopPrank();

        // Note Alice's sfrxUSD asset value after setLastSync
        uint256 aliceAssetBalAfterSetLastSync = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Alice should have earned 5% AGAIN
        assertApproxEqRel(
            aliceAssetBalAfterSetLastSync,
            (aliceAssetBalAfter1stWarp * 1.05e18) / 1e18,
            0.0005e18,
            "Alice's sfrxUSD asset value should have increased 5% AGAIN [test_1YrTtl_BackToTheFuture]"
        );
    }

    function test_1YrTtl_ResetAll() public {
        // Nobody else deposits
        // Reset lastSync, pricePerShareStored, and pricePerShareIncPerSecond after a year, removing all of Alice's gains
        // ======================================

        // Sync
        sfrxUSD2.sync();

        // Note initial pricePerShare
        uint256 _initialPPS = sfrxUSD2.pricePerShare();

        // Note Alice's sfrxUSD asset value initially
        uint256 aliceAssetBalInitial = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;
        console.log("aliceAssetBalInitial: ", aliceAssetBalInitial);

        // Warp one year ahead
        _warpToAndRollOne(block.timestamp + ONE_YEAR);

        // Note Alice's sfrxUSD asset value after the warp
        uint256 aliceAssetBalAfter1stWarp = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Sync to "save" pricePerShareStored and lastSync
        sfrxUSD2.sync();

        // Alice should have earned 5%
        assertApproxEqRel(
            aliceAssetBalAfter1stWarp,
            (aliceAssetBalInitial * 1.05e18) / 1e18,
            0.0005e18,
            "Alice's sfrxUSD asset value should have increased 5% [test_1YrTtl_ResetAll]"
        );

        // Set PPS back to the starting value, but leave lastSync and pricePerShareIncPerSecond alone
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.setAllPricingParams(_initialPPS, sfrxUSD2.pricePerShareIncPerSecond(), block.timestamp);
        vm.stopPrank();

        // Note Alice's sfrxUSD asset value after setAllPricingParams
        uint256 aliceAssetBalAfterSetLastSync = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Alice should have earned nothing
        assertApproxEqRel(
            aliceAssetBalAfterSetLastSync,
            aliceAssetBalInitial,
            0.0005e18,
            "Alice's sfrxUSD earnings should have been wiped out back to her initial amount [test_1YrTtl_ResetAll]"
        );

        // But now set lastSync back a year
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.setAllPricingParams(_initialPPS, sfrxUSD2.pricePerShareIncPerSecond(), block.timestamp - ONE_YEAR);
        vm.stopPrank();

        // Alice should have earned back her 5%
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            (aliceAssetBalInitial * 1.05e18) / 1e18,
            0.0005e18,
            "Alice's sfrxUSD should have gotten back her 5% [test_1YrTtl_ResetAll]"
        );
    }

    function test_1YrTtl_HighAPYOnly() public {
        // Nobody else deposits
        // PPSPS increased to target 5000% APY
        // ======================================
        // Raise the PPSPS
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.setPricePerShareIncPerSecond(sfrxUSD2.calcPPSIPSForGivenAPY(50e18));
        vm.stopPrank();

        // Note Alice's sfrxUSD asset value after
        aliceAssetBalAfter = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Warp one year ahead
        _warpToAndRollOne(block.timestamp + ONE_YEAR);

        // Alice should have earned 5000%
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            (aliceAssetBalAfter * 50e18) / 1e18,
            0.0005e18,
            "Alice's sfrxUSD asset value should have rose 5000% [test_1YrTtl_HighAPYOnly]"
        );
    }

    function test_1YrTtl_HighTVLOnly() public {
        // Nobody else deposits
        // No PPS changes
        // 10T sfrxUSD is given to Alice
        // ======================================

        // Note Alice's sfrxUSD balance and asset value before
        console.log(unicode"\n🐇🐇🐇🐇🐇 Alice Before 🐇🐇🐇🐇🐇");
        aliceShareBalBefore = sfrxUSD2.balanceOf(alice);
        aliceAssetBalBefore = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;
        console.log("aliceShareBalBefore (dec): ", aliceShareBalBefore.decimalString(18, false));
        console.log("aliceAssetBalBefore (dec): ", aliceAssetBalBefore.decimalString(18, false));

        // Mint 10T sfrxUSD to Alice
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.minter_mint(alice, 10 * ONE_TRILLION_E18);
        vm.stopPrank();

        // Note Alice's sfrxUSD balance and asset value after
        console.log(unicode"\n🐇🐇🐇🐇🐇 Alice After 🐇🐇🐇🐇🐇");
        aliceShareBalAfter = sfrxUSD2.balanceOf(alice);
        aliceAssetBalAfter = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;
        console.log("aliceShareBalAfter (dec): ", aliceShareBalAfter.decimalString(18, false));
        console.log("aliceAssetBalAfter (dec): ", aliceAssetBalAfter.decimalString(18, false));

        // Warp one year ahead
        _warpToAndRollOne(block.timestamp + ONE_YEAR);

        // Alice should have earned 5%
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            (aliceAssetBalAfter * 1.05e18) / 1e18,
            0.0005e18,
            "Alice's sfrxUSD asset value should have rose 5% [test_1YrTtl_HighTVLOnly]"
        );
    }

    function test_1YrTtl_HighAPYAndTVL() public {
        // Nobody else deposits
        // PPSPS increased to target 5000% APY (50x)
        // 10T sfrxUSD is given to Alice
        // Meant to test for overflows
        // ======================================
        // Raise the PPSPS
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.setPricePerShareIncPerSecond(sfrxUSD2.calcPPSIPSForGivenAPY(50e18));

        // Mint 10T sfrxUSD to Alice
        sfrxUSD2.minter_mint(alice, 10 * ONE_TRILLION_E18);

        vm.stopPrank();

        // Note Alice's sfrxUSD asset value after
        aliceAssetBalAfter = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Warp one year ahead
        _warpToAndRollOne(block.timestamp + ONE_YEAR);

        // Alice should have earned 5000% (50x)
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            (aliceAssetBalAfter * 50e18) / 1e18,
            0.0005e18,
            "Alice's sfrxUSD asset value should have rose 5000% [test_1YrTtl_HighAPYAndTVL]"
        );
    }

    function test_1YrTtl_HalfSlashed() public {
        // Nobody else deposits
        // Alice earns at 5% for 6 months (2.5% thus far)
        // But then unfortunately 50% of the assets behind sfrxUSD are hacked so the PPS has to be slashed by 50%
        // APY is still 5% though (remaining assets are still earning)
        // ======================================

        // Warp six months ahead
        _warpToAndRollOne(block.timestamp + (ONE_MONTH * 6));

        // Sync
        sfrxUSD2.sync();

        // 50% of the sfrxUSD assets are stolen so PPS must be cut in half.
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.setPricePerShareStored(sfrxUSD2.pricePerShare() / 2);
        vm.stopPrank();

        // Alice should lose half of her asset value
        // She did earn approx 2.5% first though (25 frxUSD)
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            1025e18 / 2,
            0.0005e18,
            "Alice's sfrxUSD asset value should be close to 512.5 frxUSD [test_1YrTtl_HalfSlashed #1]"
        );

        // Note Alice's sfrxUSD asset value after the slash
        aliceAssetBalAfter = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Warp six months again
        _warpToAndRollOne(block.timestamp + (ONE_MONTH * 6));

        // Alice should have earned 5% for six months off of her post-slash sfrxUSD
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            (aliceAssetBalAfter * 1.025e18) / 1e18,
            0.0005e18,
            "Alice's sfrxUSD asset value should be close to 525.3125 frxUSD [test_1YrTtl_HalfSlashed #2]"
        );
    }

    // ===================================================
    // POSITIVE PPS CHANGES
    // ===================================================

    // NO NEW DEPOSITORS
    // =========

    function test_1YrTtl_6MoPPSPosChange() public {
        // Nobody else deposits
        // PPS raised 6 months in. Target APY is now 10%
        // ======================================

        // Warp six months ahead
        _warpToAndRollOne(block.timestamp + (ONE_MONTH * 6));

        // Sync
        sfrxUSD2.sync();

        // Note Alice's sfrxUSD asset value before the APY raise
        aliceAssetBalBefore = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Raise the APY target to 10%
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.setPricePerShareIncPerSecond(sfrxUSD2.calcPPSIPSForGivenAPY(1.1e18));
        vm.stopPrank();

        // Warp six months again
        _warpToAndRollOne(block.timestamp + (ONE_MONTH * 6));

        // Alice should have earned AT 5% for six months (2.5% since half a year),
        // then AT 10% for the next 6 months (5% since half a year)
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            (aliceAssetBalBefore * 1.05e18) / 1e18,
            0.0025e18,
            "[test_1YrTtl_6MoPPSPosChange_MaxFullyRaised]"
        );
    }

    // NEW DEPOSITOR
    // =========

    function _bob5MAndDoubleWarp() internal {
        // Warp three months ahead
        _warpToAndRollOne(block.timestamp + (ONE_MONTH * 3));

        // Mint 5M sfrxUSD to Bob
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.minter_mint(bob, 5 * ONE_MILLION_E18);
        vm.stopPrank();

        // Warp three months ahead
        _warpToAndRollOne(block.timestamp + (ONE_MONTH * 3));

        // Sync
        sfrxUSD2.sync();
    }

    function test_1YrTtl_3MoBob_6MoPPSPosChange() public {
        // Bob deposits 5M worth of sfrxUSD 3 months in
        // PPS raised 6 months in. Target APY is now 10%
        // ======================================

        // Warp three months ahead, mint 5M sfrxUSD to Bob, then warp another three months
        _bob5MAndDoubleWarp();

        // Note Alice's sfrxUSD asset value before the APY raise
        aliceAssetBalBefore = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Raise the APY target to 10%
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.setPricePerShareIncPerSecond(sfrxUSD2.calcPPSIPSForGivenAPY(1.1e18));
        vm.stopPrank();

        // Warp six months again
        _warpToAndRollOne(block.timestamp + (ONE_MONTH * 6));

        // Alice should have earned AT 5% for six months (2.5% since half a year),
        // then AT 10% for the next 6 months (5% since half a year)
        // Bob's entry should have had no effect on her earnings
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            (aliceAssetBalBefore * 1.05e18) / 1e18,
            0.0025e18,
            "[test_1YrTtl_3MoBob_6MoPPSPosChange_MaxFullyRaised]"
        );
    }

    // ===================================================
    // NEGATIVE PPS CHANGES
    // ===================================================

    // NO NEW DEPOSITORS
    // =========

    function test_1YrTtl_MidPPSNegChange() public {
        // Nobody else deposits
        // PPS lowered 6 months in. Target APY is now 2.5%
        // ======================================
        // Warp six months ahead
        _warpToAndRollOne(block.timestamp + (ONE_MONTH * 6));

        // Sync
        sfrxUSD2.sync();

        // Note Alice's sfrxUSD asset value before the APY lowering
        aliceAssetBalBefore = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Lower the APY target to 2.5%
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.setPricePerShareIncPerSecond(sfrxUSD2.calcPPSIPSForGivenAPY(1.025e18));
        vm.stopPrank();

        // Warp six months again
        _warpToAndRollOne(block.timestamp + (ONE_MONTH * 6));

        // Alice should have earned AT 5% for six months (2.5% since half a year),
        // then AT 2.5% for the next 6 months (1.25% since half a year)
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            (aliceAssetBalBefore * 1.0125e18) / 1e18,
            0.0025e18,
            "[test_1YrTtl_MidPPSNegChange_MaxNotLowered]"
        );
    }

    // NEW DEPOSITOR
    // =========

    function test_1YrTtl_3MoBob_MidPPSNegChange() public {
        // Bob deposits 5M worth of sfrxUSD 3 months in
        // PPS lowered 6 months in. Target APY is now 2.5%
        // ======================================

        // Warp three months ahead, mint 5M sfrxUSD to Bob, then warp another three months
        _bob5MAndDoubleWarp();

        // Note Alice's sfrxUSD asset value before the APY lowering
        aliceAssetBalBefore = (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18;

        // Lower the APY target to 2.5%
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.setPricePerShareIncPerSecond(sfrxUSD2.calcPPSIPSForGivenAPY(1.025e18));
        vm.stopPrank();

        // Warp six months again
        _warpToAndRollOne(block.timestamp + (ONE_MONTH * 6));

        // Alice should have earned AT 5% for six months (2.5% since half a year),
        // then AT 2.5% for the next 6 months (1.25% since half a year)
        // Bob's entry should have had no effect on her earnings
        assertApproxEqRel(
            (sfrxUSD2.balanceOf(alice) * sfrxUSD2.pricePerShare()) / 1e18,
            (aliceAssetBalBefore * 1.0125e18) / 1e18,
            0.0025e18,
            "[test_1YrTtl_3MoBob_MidPPSNegChange_MaxNotLowered]"
        );
    }
}
