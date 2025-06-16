// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "./BaseTestStakedFrxUSD2.sol";
import "../../contracts/StakedFrax.sol";
import { DecimalStringHelper } from "src/test/helpers/DecimalStringHelper.sol";
import { LinearRewardsQuasiErc4626 } from "src/contracts/LinearRewardsQuasiErc4626.sol";
import { StakedFrxUSD2 } from "src/contracts/StakedFrxUSD2.sol";
import { Timelock2Step } from "frax-std/access-control/v2/Timelock2Step.sol";

contract TestMintDepositWithdrawRedeem is BaseTestStakedFrxUSD2 {
    using DecimalStringHelper for uint256;

    // For testing
    uint256 frxUSDBefore;
    uint256 sfrxUSDBefore;

    function setUp() public {
        defaultSetup();

        // Give Alice some additional frxUSD
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        frxUSDErc20.transfer(alice, 1000e18);
    }

    function test_MDWR() public {
        // Alice should not be able to do any mints, deposits, redeems, or withdrawals
        // ------------------------------------------------
        // Become Alice
        startHoax(alice);

        // Approve frxUSD
        frxUSDErc20.approve(stakedFrxUSD2Address, 1000e18);

        // Mint (should fail)
        vm.expectRevert(LinearRewardsQuasiErc4626.MintRedeemsDisabled.selector);
        sfrxUSD2.mint(100e18, alice);

        // Deposit (should fail)
        vm.expectRevert(LinearRewardsQuasiErc4626.MintRedeemsDisabled.selector);
        sfrxUSD2.deposit(100e18, alice);

        // Deposit with signature (should fail)
        vm.expectRevert(LinearRewardsQuasiErc4626.MintRedeemsDisabled.selector);
        sfrxUSD2.depositWithSignature(100e18, alice, 9_999_999_999, true, 0, bytes32(0), bytes32(0));

        // Withdraw (should fail)
        vm.expectRevert(LinearRewardsQuasiErc4626.MintRedeemsDisabled.selector);
        sfrxUSD2.withdraw(100e18, alice, alice);

        // Redeem (should fail)
        vm.expectRevert(LinearRewardsQuasiErc4626.MintRedeemsDisabled.selector);
        sfrxUSD2.redeem(100e18, alice, alice);

        // Test convertToAssets and convertToShares
        // ------------------------------------------------
        assertApproxEqRel(
            sfrxUSD2.convertToAssets(1e18),
            sfrxUSD2.pricePerShare(),
            0.001e18,
            "Unexpected convertToAssets result"
        );
        assertApproxEqRel(
            sfrxUSD2.convertToShares(1e18),
            (1e18 * 1e18) / sfrxUSD2.pricePerShare(),
            0.0001e18,
            "Unexpected convertToShares result"
        );

        // Preview functions should return 0
        // ------------------------------------------------
        assert(sfrxUSD2.previewMint(100e18) == 0);
        assert(sfrxUSD2.previewDeposit(100e18) == 0);
        assert(sfrxUSD2.previewWithdraw(100e18) == 0);
        assert(sfrxUSD2.previewRedeem(100e18) == 0);

        // Max functions should return 0
        // ------------------------------------------------
        assert(sfrxUSD2.maxMint(alice) == 0);
        assert(sfrxUSD2.maxDeposit(alice) == 0);
        assert(sfrxUSD2.maxWithdraw(alice) == 0);
        assert(sfrxUSD2.maxRedeem(alice) == 0);

        // Burning should not recover any frxUSD
        // ------------------------------------------------
        frxUSDBefore = frxUSDErc20.balanceOf(alice);
        sfrxUSDBefore = sfrxUSD2.balanceOf(alice);
        sfrxUSD2.burn(1e18);
        assertEq(frxUSDErc20.balanceOf(alice), frxUSDBefore, "Burning sfrxUSD should not return frxUSD");
        assertEq(
            sfrxUSD2.balanceOf(alice),
            sfrxUSDBefore - 1e18,
            "Burning sfrxUSD should have decreased Alices sfrxUSD"
        );

        // Alice should not be able to do any privileged mints/burns either
        // ------------------------------------------------
        // Alice tries to minter mint (should fail)
        vm.expectRevert(StakedFrxUSD2.OnlyMinters.selector);
        sfrxUSD2.minter_mint(alice, 1e18);

        // Alice tries to minter burn (should fail)
        vm.expectRevert(StakedFrxUSD2.OnlyMinters.selector);
        sfrxUSD2.minter_burn_from(alice, 1e18);

        // End Alice hoax
        vm.stopPrank();

        // Make the owner a minter
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.addMinter(Constants.Mainnet.FRAX_ERC20_OWNER);

        // Alice cannot make herself a minter
        // console.log("this address: ", address(this));
        // console.log("alice address: ", alice);
        // Need to use startHoax vs hoax here because hoax is consumed before the error is thrown and it will want address(this) instead
        startHoax(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Timelock2Step.AddressIsNotTimelock.selector, sfrxUSD2.timelockAddress(), alice)
        );
        sfrxUSD2.addMinter(alice);
        vm.stopPrank();

        // Alice is made into a minter by the timelock
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.addMinter(alice);

        // Alice should be able to mint as a minter now
        sfrxUSDBefore = sfrxUSD2.balanceOf(alice);
        console.log("sfrxUSD2 mint before #1 (dec'd): ", sfrxUSDBefore.decimalString(18, false));
        vm.prank(alice);
        sfrxUSD2.minter_mint(alice, 1e18);
        console.log("sfrxUSD2 mint after #1 (dec'd): ", sfrxUSD2.balanceOf(alice).decimalString(18, false));
        assertEq(sfrxUSD2.balanceOf(alice), sfrxUSDBefore + 1e18, "sfrxUSD2 mint balance #1 mismatch");

        // Alice should be able to burn as a minter now
        sfrxUSDBefore = sfrxUSD2.balanceOf(alice);
        console.log("sfrxUSD2 burn before #1 (dec'd): ", sfrxUSDBefore.decimalString(18, false));
        vm.prank(alice);
        sfrxUSD2.minter_burn_from(alice, 1e18);
        console.log("sfrxUSD2 burn after #1 (dec'd): ", sfrxUSD2.balanceOf(alice).decimalString(18, false));
        assertEq(sfrxUSD2.balanceOf(alice), sfrxUSDBefore - 1e18, "sfrxUSD2 burn balance #1 mismatch");

        // Alice cannot remove herself as a minter
        startHoax(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Timelock2Step.AddressIsNotTimelock.selector, sfrxUSD2.timelockAddress(), alice)
        );
        sfrxUSD2.removeMinter(alice);
        vm.stopPrank();

        // Alice is removed as a minter by the timelock
        vm.prank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.removeMinter(alice);

        // Alice tries to mint again (should fail)
        vm.prank(alice);
        vm.expectRevert(StakedFrxUSD2.OnlyMinters.selector);
        sfrxUSD2.minter_mint(alice, 1e18);

        // Alice tries to minter burn again (should fail)
        vm.prank(alice);
        vm.expectRevert(StakedFrxUSD2.OnlyMinters.selector);
        sfrxUSD2.minter_burn_from(alice, 1e18);

        // Alice is once again added as a minter
        vm.prank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.addMinter(alice);

        // Alice should be able to mint as a minter (again) now
        sfrxUSDBefore = sfrxUSD2.balanceOf(alice);
        console.log("sfrxUSD mint before #2 (dec'd): ", sfrxUSDBefore.decimalString(18, false));
        vm.prank(alice);
        sfrxUSD2.minter_mint(alice, 1e18);
        console.log("sfrxUSD mint after #2 (dec'd): ", sfrxUSD2.balanceOf(alice).decimalString(18, false));
        assertEq(sfrxUSD2.balanceOf(alice), sfrxUSDBefore + 1e18, "sfrxUSD2 mint balance #2 mismatch");

        // Alice should be able to burn as a minter (again) now
        sfrxUSDBefore = sfrxUSD2.balanceOf(alice);
        console.log("sfrxUSD2 burn before #2 (dec'd): ", sfrxUSDBefore.decimalString(18, false));
        vm.prank(alice);
        sfrxUSD2.minter_burn_from(alice, 1e18);
        console.log("sfrxUSD2 burn after #2 (dec'd): ", sfrxUSD2.balanceOf(alice).decimalString(18, false));
        assertEq(sfrxUSD2.balanceOf(alice), sfrxUSDBefore - 1e18, "sfrxUSD2 burn balance #2 mismatch");

        // Alice is removed as a minter
        vm.prank(Constants.Mainnet.FRAX_ERC20_OWNER);
        sfrxUSD2.removeMinter(alice);

        // End hoax
        vm.stopPrank();
    }
}
