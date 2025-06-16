// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FrxUSD } from "../../contracts/FrxUSD.sol";
import { FrxUSDCustodian } from "../../contracts/FrxUSDCustodian.sol";
import { FrxUSDCustodianFactory } from "../../contracts/FrxUSDCustodianFactory.sol";
import "../../Constants.sol" as Constants;

contract FrxUSDCustodianTest is FraxTest, Constants.Helper {
    FrxUSD public frxUSD = FrxUSD(0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29);
    IERC20 public legacyFRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    FrxUSDCustodian frxUSDCustodian;

    function defaultSetup(IERC20 _custodianTkn) public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_571_861);
        FrxUSDCustodianFactory frxUSDCustodianFactory = new FrxUSDCustodianFactory(
            Constants.Mainnet.FRAX_ERC20_OWNER,
            address(frxUSD)
        );
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        frxUSDCustodian = FrxUSDCustodian(
            frxUSDCustodianFactory.deployCustodian(address(_custodianTkn), 1000e18, 0.01e18, 0.01e18)
        );
        FrxUSD(frxUSD).addMinter(address(frxUSDCustodian));
        vm.stopPrank();
    }

    function test_deployment() public {
        defaultSetup(legacyFRAX);
        assertEq(address(frxUSDCustodian.frxUSD()), address(frxUSD), "frxUSD should be set");
        assertEq(address(frxUSDCustodian.custodianTkn()), address(legacyFRAX), "custodianTkn should be set");
        assertEq(frxUSDCustodian.owner(), Constants.Mainnet.FRAX_ERC20_OWNER, "owner should be set");
        assertEq(frxUSDCustodian.mintFee(), 0.01e18, "fee should be set");
        assertEq(frxUSDCustodian.redeemFee(), 0.01e18, "fee should be set");
        assertEq(frxUSDCustodian.mintCap(), 1000e18, "mintCap should be set");
        vm.expectRevert(); // Revert when initializing again
        frxUSDCustodian.initialize(Constants.Mainnet.FRAX_ERC20_OWNER, 1000e18, 0.01e18, 0.01e18);
    }

    function test_mint() public {
        defaultSetup(legacyFRAX);
        address whale = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        vm.startPrank(whale);

        vm.expectRevert(); // Revert without approval
        frxUSDCustodian.mint(100e18, address(whale));

        legacyFRAX.approve(address(frxUSDCustodian), 102e18);
        uint256 expectedIn = uint256(100e18 * 1e18) / (1e18 - 0.01e18);
        uint256 expectedOut = 100e18;
        uint256 balanceFrxUSD = frxUSD.balanceOf(address(whale));
        uint256 balanceLegacyFRAX = legacyFRAX.balanceOf(address(whale));
        uint256 totalSupply = frxUSD.totalSupply();
        uint256 previewMint = frxUSDCustodian.previewMint(100e18);
        frxUSDCustodian.mint(100e18, address(whale));
        uint256 amountOut = frxUSD.balanceOf(address(whale)) - balanceFrxUSD;
        uint256 amountIn = balanceLegacyFRAX - legacyFRAX.balanceOf(address(whale));
        assertApproxEqAbs(amountOut, expectedOut, 1, "Amount out should be correct");
        assertApproxEqAbs(amountIn, expectedIn, 1, "Amount in should be correct");
        assertApproxEqAbs(amountIn, previewMint, 1, "Amount in should be equal to preview");
        assertApproxEqAbs(totalSupply + amountOut, frxUSD.totalSupply(), 1, "totalSupply incorrect");
        assertApproxEqAbs(frxUSDCustodian.frxUSDMinted(), amountOut, 1, "frxUSDMinted incorrect");
        assertApproxEqAbs(legacyFRAX.balanceOf(address(frxUSDCustodian)), amountIn, 1, "custodian balance incorrect");
        vm.stopPrank();
    }

    function test_deposit() public {
        defaultSetup(legacyFRAX);
        address whale = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        vm.startPrank(whale);

        vm.expectRevert(); // Revert without approval
        frxUSDCustodian.deposit(100e18, address(whale));

        legacyFRAX.approve(address(frxUSDCustodian), 100e18);
        uint256 expectedIn = 100e18;
        uint256 expectedOut = (uint256(100e18) * (1e18 - 0.01e18)) / 1e18;
        uint256 balanceFrxUSD = frxUSD.balanceOf(address(whale));
        uint256 balanceLegacyFRAX = legacyFRAX.balanceOf(address(whale));
        uint256 totalSupply = frxUSD.totalSupply();
        uint256 previewDeposit = frxUSDCustodian.previewDeposit(100e18);
        frxUSDCustodian.deposit(100e18, address(whale));
        uint256 amountOut = frxUSD.balanceOf(address(whale)) - balanceFrxUSD;
        uint256 amountIn = balanceLegacyFRAX - legacyFRAX.balanceOf(address(whale));
        assertApproxEqAbs(amountOut, expectedOut, 1, "Amount out should be correct");
        assertApproxEqAbs(amountIn, expectedIn, 1, "Amount in should be correct");
        assertApproxEqAbs(amountOut, previewDeposit, 1, "Amount out should be equal to preview");
        assertApproxEqAbs(totalSupply + amountOut, frxUSD.totalSupply(), 1, "totalSupply incorrect");
        assertApproxEqAbs(frxUSDCustodian.frxUSDMinted(), amountOut, 1, "frxUSDMinted incorrect");
        vm.stopPrank();
    }

    function test_redeem() public {
        defaultSetup(legacyFRAX);
        address whale = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        vm.startPrank(whale);

        legacyFRAX.approve(address(frxUSDCustodian), 102e18);
        frxUSDCustodian.mint(100e18, address(whale));

        frxUSD.approve(address(frxUSDCustodian), 100e18);
        uint256 expectedIn = 100e18;
        uint256 expectedOut = (uint256(100e18) * (1e18 - 0.01e18)) / 1e18;
        uint256 balanceFrxUSD = frxUSD.balanceOf(address(whale));
        uint256 balanceLegacyFRAX = legacyFRAX.balanceOf(address(whale));
        uint256 totalSupply = frxUSD.totalSupply();
        uint256 previewRedeem = frxUSDCustodian.previewRedeem(100e18);
        frxUSDCustodian.redeem(100e18, address(whale), address(whale));
        uint256 amountOut = legacyFRAX.balanceOf(address(whale)) - balanceLegacyFRAX;
        uint256 amountIn = balanceFrxUSD - frxUSD.balanceOf(address(whale));
        assertApproxEqAbs(amountOut, expectedOut, 1, "Amount out should be correct");
        assertApproxEqAbs(amountIn, expectedIn, 1, "Amount in should be correct");
        assertApproxEqAbs(amountOut, previewRedeem, 1, "Amount out should be equal to preview");
        assertApproxEqAbs(totalSupply - amountIn, frxUSD.totalSupply(), 1, "totalSupply incorrect");
        assertApproxEqAbs(frxUSDCustodian.frxUSDMinted(), 0, 1, "frxUSDMinted incorrect");
        vm.stopPrank();
    }

    function test_withdraw() public {
        defaultSetup(legacyFRAX);
        address whale = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        vm.startPrank(whale);

        legacyFRAX.approve(address(frxUSDCustodian), 112e18);
        frxUSDCustodian.mint(110e18, address(whale));

        frxUSD.approve(address(frxUSDCustodian), 102e18);
        uint256 expectedIn = (uint256(100e18) * 1e18) / (1e18 - 0.01e18);
        uint256 expectedOut = 100e18;
        uint256 balanceFrxUSD = frxUSD.balanceOf(address(whale));
        uint256 balanceLegacyFRAX = legacyFRAX.balanceOf(address(whale));
        uint256 totalSupply = frxUSD.totalSupply();
        uint256 previewWithdraw = frxUSDCustodian.previewWithdraw(100e18);
        frxUSDCustodian.withdraw(100e18, address(whale), address(whale));
        uint256 amountOut = legacyFRAX.balanceOf(address(whale)) - balanceLegacyFRAX;
        uint256 amountIn = balanceFrxUSD - frxUSD.balanceOf(address(whale));
        assertApproxEqAbs(amountOut, expectedOut, 1, "Amount out should be correct");
        assertApproxEqAbs(amountIn, expectedIn, 1, "Amount in should be correct");
        assertApproxEqAbs(amountIn, previewWithdraw, 1, "Amount out should be equal to preview");
        assertApproxEqAbs(totalSupply - amountIn, frxUSD.totalSupply(), 1, "totalSupply incorrect");
        assertApproxEqAbs(frxUSDCustodian.frxUSDMinted(), 110e18 - amountIn, 1, "frxUSDMinted incorrect");
        vm.stopPrank();
    }

    function test_mintCap() public {
        defaultSetup(legacyFRAX);
        address whale = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        vm.startPrank(whale);

        legacyFRAX.approve(address(frxUSDCustodian), 1_000_000e18);
        frxUSD.approve(address(frxUSDCustodian), 1_000_000e18);
        uint256 maxMint = frxUSDCustodian.maxMint(whale);
        assertApproxEqAbs(maxMint, frxUSDCustodian.mintCap(), 1, "maxMint should be equal to mintCap");
        vm.expectRevert(); // Revert when minting too much
        frxUSDCustodian.mint(maxMint + 1, address(whale));

        // Minting the cap should work
        frxUSDCustodian.mint(maxMint, address(whale));

        vm.expectRevert(); // No more minting when at the cap
        frxUSDCustodian.mint(1, address(whale));

        // Redeem some
        frxUSDCustodian.redeem(100, address(whale), address(whale));

        // Minting should work again
        frxUSDCustodian.mint(frxUSDCustodian.maxMint(whale), address(whale));

        vm.expectRevert(); // At the cap again
        frxUSDCustodian.mint(1, address(whale));

        vm.stopPrank();
    }

    function test_withdrawCap() public {
        defaultSetup(legacyFRAX);
        address whale = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        vm.startPrank(frxUSDCustodian.owner());
        frxUSD.addMinter(frxUSDCustodian.owner());
        frxUSD.minter_mint(address(whale), 1_000_000e18);
        vm.stopPrank();
        vm.startPrank(whale);

        legacyFRAX.approve(address(frxUSDCustodian), 1_000_000e18);
        frxUSD.approve(address(frxUSDCustodian), 1_000_000e18);
        frxUSDCustodian.deposit(100e18, address(whale));

        uint256 maxWithdraw = frxUSDCustodian.maxWithdraw(whale);
        assertApproxEqAbs(
            maxWithdraw,
            legacyFRAX.balanceOf(address(frxUSDCustodian)),
            1,
            "maxWithdraw should be equal to balance in the custodian"
        );

        vm.expectRevert(); // Revert when withdrawing too much
        frxUSDCustodian.withdraw(maxWithdraw + 1, address(whale), address(whale));

        // Withdrawing the cap should work
        frxUSDCustodian.withdraw(maxWithdraw, address(whale), address(whale));

        // No more withdrawing when at the cap
        vm.expectRevert();
        frxUSDCustodian.withdraw(1, address(whale), address(whale));

        // Deposit some more
        frxUSDCustodian.deposit(100e18, address(whale));

        // Withdrawing should work again
        frxUSDCustodian.withdraw(frxUSDCustodian.maxWithdraw(whale) - 1, address(whale), address(whale));

        vm.stopPrank();
    }

    function test_ownerFunctionality() public {
        defaultSetup(legacyFRAX);
        address whale = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        vm.startPrank(whale);

        legacyFRAX.approve(address(frxUSDCustodian), 1_000_000e18);
        frxUSD.approve(address(frxUSDCustodian), 1_000_000e18);

        // Mint the cap
        frxUSDCustodian.mint(frxUSDCustodian.maxMint(whale), address(whale));

        vm.expectRevert(); // Revert when not owner
        frxUSDCustodian.setMintCap(2000e18);

        vm.expectRevert(); // Revert when not owner
        frxUSDCustodian.setMintRedeemFee(0.02e18, 0.03e18);

        vm.expectRevert(); // Revert when not owner
        frxUSDCustodian.recoverERC20(address(legacyFRAX), 1000e18);
        vm.stopPrank();

        vm.startPrank(frxUSDCustodian.owner());
        frxUSDCustodian.setMintCap(2000e18);
        assertEq(frxUSDCustodian.mintCap(), 2000e18, "mintCap should be set");

        frxUSDCustodian.setMintRedeemFee(0.02e18, 0.03e18);
        assertEq(frxUSDCustodian.mintFee(), 0.02e18, "fee should be set");
        assertEq(frxUSDCustodian.redeemFee(), 0.03e18, "fee should be set");

        uint256 balance = legacyFRAX.balanceOf(frxUSDCustodian.owner());
        frxUSDCustodian.recoverERC20(address(legacyFRAX), 1000e18);
        assertEq(legacyFRAX.balanceOf(frxUSDCustodian.owner()), balance + 1000e18, "ERC20 should be recovered");
        vm.stopPrank();

        vm.startPrank(whale);
        // Mint is possible again
        frxUSDCustodian.mint(1000e18, address(whale));
        vm.stopPrank();
    }

    function test_forkTest() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_636_725);
        FrxUSDCustodianFactory frxUSDCustodianFactory = FrxUSDCustodianFactory(
            0xc4B490154c91C140E5b246147Eb1d6973b7b035D
        );
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        frxUSDCustodian = FrxUSDCustodian(
            frxUSDCustodianFactory.deployCustodian(address(legacyFRAX), 1000e18, 0.0e18, 0.0001e18)
        );
        FrxUSD(frxUSD).addMinter(address(frxUSDCustodian));
        vm.stopPrank();
        address whale = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        vm.startPrank(whale);
        console.log("Before FRAX  :", legacyFRAX.balanceOf(whale));
        console.log("Before frxUSD:", frxUSD.balanceOf(whale));
        legacyFRAX.approve(address(frxUSDCustodian), 100e18);
        frxUSDCustodian.deposit(100e18, whale);
        console.log("After FRAX   :", legacyFRAX.balanceOf(whale));
        console.log("After frxUSD :", frxUSD.balanceOf(whale));
        frxUSD.approve(address(frxUSDCustodian), 100e18);
        frxUSDCustodian.redeem(100e18, whale, whale);
        console.log("After2 FRAX  :", legacyFRAX.balanceOf(whale));
        console.log("After2 frxUSD:", frxUSD.balanceOf(whale));
        vm.stopPrank();
    }
}
