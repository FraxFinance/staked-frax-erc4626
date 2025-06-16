// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FrxUSD } from "../../contracts/FrxUSD.sol";
import { FrxUSDCustodianWithOracle } from "../../contracts/FrxUSDCustodianWithOracle.sol";
import { FrxUSDCustodianWithOracleFactory } from "../../contracts/FrxUSDCustodianWithOracleFactory.sol";
import { AggregatorV3Interface } from "../../contracts/interfaces/AggregatorV3Interface.sol";
import "../../Constants.sol" as Constants;

contract FrxUSDCustodianWithOracleTest is FraxTest, Constants.Helper {
    FrxUSD public frxUSD = FrxUSD(0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29);
    IERC20 public USTB = IERC20(0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e);
    AggregatorV3Interface USTBOracle = AggregatorV3Interface(0xE4fA682f94610cCd170680cc3B045d77D9E528a8);
    FrxUSDCustodianWithOracle frxUSDCustodian;
    uint256 custodianOraclePrice;

    function defaultSetup(IERC20 _custodianTkn) public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_571_861);
        FrxUSDCustodianWithOracleFactory frxUSDCustodianFactory = new FrxUSDCustodianWithOracleFactory(
            Constants.Mainnet.FRAX_ERC20_OWNER,
            address(frxUSD)
        );
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        frxUSDCustodian = FrxUSDCustodianWithOracle(
            frxUSDCustodianFactory.deployCustodian(
                address(_custodianTkn),
                address(USTBOracle),
                60 * 24 * 24 * 7,
                10_000e18,
                0.01e18,
                0.01e18
            )
        );
        FrxUSD(frxUSD).addMinter(address(frxUSDCustodian));
        vm.stopPrank();
        vm.startPrank(0x7747940aDBc7191f877a9B90596E0DA4f8deb2Fe);
        AllowList(0x02f1fA8B196d21c7b733EB2700B825611d8A38E5).setEntityIdForAddress(34, address(frxUSDCustodian));
        AllowList(0x02f1fA8B196d21c7b733EB2700B825611d8A38E5).setEntityIdForAddress(
            34,
            address(Constants.Mainnet.FRAX_ERC20_OWNER)
        );
        vm.stopPrank();
        custodianOraclePrice = frxUSDCustodian.getCustodianOraclePrice();
    }

    function test_deployment() public {
        defaultSetup(USTB);
        assertEq(address(frxUSDCustodian.frxUSD()), address(frxUSD), "frxUSD should be set");
        assertEq(address(frxUSDCustodian.custodianTkn()), address(USTB), "custodianTkn should be set");
        assertEq(frxUSDCustodian.owner(), Constants.Mainnet.FRAX_ERC20_OWNER, "owner should be set");
        assertEq(frxUSDCustodian.mintFee(), 0.01e18, "fee should be set");
        assertEq(frxUSDCustodian.redeemFee(), 0.01e18, "fee should be set");
        assertEq(frxUSDCustodian.mintCap(), 10_000e18, "mintCap should be set");
        vm.expectRevert(); // Revert when initializing again
        frxUSDCustodian.initialize(Constants.Mainnet.FRAX_ERC20_OWNER, 1000e18, 0.01e18, 0.01e18);
        vm.expectRevert(); // Revert when initializing again
        frxUSDCustodian.initialize(
            Constants.Mainnet.FRAX_ERC20_OWNER,
            address(USTBOracle),
            60 * 24 * 24 * 7,
            1000e18,
            0.01e18,
            0.01e18
        );
    }

    function test_mint() public {
        defaultSetup(USTB);
        address whale = 0x5138D77d51dC57983e5A653CeA6e1C1aa9750A39;
        vm.startPrank(whale);

        vm.expectRevert(); // Revert without approval
        frxUSDCustodian.mint(100e18, address(whale));

        USTB.approve(address(frxUSDCustodian), 102e18);
        uint256 expectedIn = uint256(100e6 * 1e18) / (1e18 - 0.01e18);
        expectedIn = (expectedIn * 1e6) / custodianOraclePrice;
        uint256 expectedOut = 100e18;
        uint256 balanceFrxUSD = frxUSD.balanceOf(address(whale));
        uint256 balanceUSTB = USTB.balanceOf(address(whale));
        uint256 totalSupply = frxUSD.totalSupply();
        uint256 previewMint = frxUSDCustodian.previewMint(100e18);
        frxUSDCustodian.mint(100e18, address(whale));
        uint256 amountOut = frxUSD.balanceOf(address(whale)) - balanceFrxUSD;
        uint256 amountIn = balanceUSTB - USTB.balanceOf(address(whale));
        assertApproxEqAbs(amountOut, expectedOut, 1, "Amount out should be correct");
        assertApproxEqAbs(amountIn, expectedIn, 1, "Amount in should be correct");
        assertApproxEqAbs(amountIn, previewMint, 1, "Amount in should be equal to preview");
        assertApproxEqAbs(totalSupply + amountOut, frxUSD.totalSupply(), 1, "totalSupply incorrect");
        assertApproxEqAbs(frxUSDCustodian.frxUSDMinted(), amountOut, 1, "frxUSDMinted incorrect");
        assertApproxEqAbs(USTB.balanceOf(address(frxUSDCustodian)), amountIn, 1, "custodian balance incorrect");
        vm.stopPrank();
    }

    function test_deposit() public {
        defaultSetup(USTB);
        address whale = 0x5138D77d51dC57983e5A653CeA6e1C1aa9750A39;
        vm.startPrank(whale);

        vm.expectRevert(); // Revert without approval
        frxUSDCustodian.deposit(100e6, address(whale));

        USTB.approve(address(frxUSDCustodian), 2000e6);
        uint256 expectedIn = 100e6;
        uint256 expectedOut = (uint256(100e18) * (1e18 - 0.01e18)) / 1e18;
        expectedOut = (expectedOut * custodianOraclePrice) / 1e6;
        uint256 balanceFrxUSD = frxUSD.balanceOf(address(whale));
        uint256 balanceUSTB = USTB.balanceOf(address(whale));
        uint256 totalSupply = frxUSD.totalSupply();
        uint256 previewDeposit = frxUSDCustodian.previewDeposit(100e6);
        frxUSDCustodian.deposit(100e6, address(whale));
        uint256 amountOut = frxUSD.balanceOf(address(whale)) - balanceFrxUSD;
        uint256 amountIn = balanceUSTB - USTB.balanceOf(address(whale));
        assertApproxEqAbs(amountOut, expectedOut, 1, "Amount out should be correct");
        assertApproxEqAbs(amountIn, expectedIn, 1, "Amount in should be correct");
        assertApproxEqAbs(amountOut, previewDeposit, 1, "Amount out should be equal to preview");
        assertApproxEqAbs(totalSupply + amountOut, frxUSD.totalSupply(), 1, "totalSupply incorrect");
        assertApproxEqAbs(frxUSDCustodian.frxUSDMinted(), amountOut, 1, "frxUSDMinted incorrect");
        vm.stopPrank();
    }

    function test_redeem() public {
        defaultSetup(USTB);
        address whale = 0x5138D77d51dC57983e5A653CeA6e1C1aa9750A39;
        vm.startPrank(whale);

        USTB.approve(address(frxUSDCustodian), 10e6);
        frxUSDCustodian.mint(100e18, address(whale));

        frxUSD.approve(address(frxUSDCustodian), 100e18);
        uint256 expectedIn = 100e18;
        uint256 expectedOut = (uint256(100e6) * (1e18 - 0.01e18)) / 1e18;
        expectedOut = (expectedOut * 1e6) / custodianOraclePrice;
        uint256 balanceFrxUSD = frxUSD.balanceOf(address(whale));
        uint256 balanceUSTB = USTB.balanceOf(address(whale));
        uint256 totalSupply = frxUSD.totalSupply();
        uint256 previewRedeem = frxUSDCustodian.previewRedeem(100e18);
        frxUSDCustodian.redeem(100e18, address(whale), address(whale));
        uint256 amountOut = USTB.balanceOf(address(whale)) - balanceUSTB;
        uint256 amountIn = balanceFrxUSD - frxUSD.balanceOf(address(whale));
        assertApproxEqAbs(amountOut, expectedOut, 1, "Amount out should be correct");
        assertApproxEqAbs(amountIn, expectedIn, 1, "Amount in should be correct");
        assertApproxEqAbs(amountOut, previewRedeem, 1, "Amount out should be equal to preview");
        assertApproxEqAbs(totalSupply - amountIn, frxUSD.totalSupply(), 1, "totalSupply incorrect");
        assertApproxEqAbs(frxUSDCustodian.frxUSDMinted(), 0, 1, "frxUSDMinted incorrect");
        vm.stopPrank();
    }

    function test_withdraw() public {
        defaultSetup(USTB);
        address whale = 0x5138D77d51dC57983e5A653CeA6e1C1aa9750A39;
        vm.startPrank(whale);

        USTB.approve(address(frxUSDCustodian), 110e6);
        frxUSDCustodian.mint(1100e18, address(whale));

        frxUSD.approve(address(frxUSDCustodian), 1100e18);
        uint256 expectedIn = (uint256(100e18) * 1e18) / (1e18 - 0.01e18);
        expectedIn = (expectedIn * custodianOraclePrice) / 1e6;
        uint256 expectedOut = 100e6;
        uint256 balanceFrxUSD = frxUSD.balanceOf(address(whale));
        uint256 balanceUSTB = USTB.balanceOf(address(whale));
        uint256 totalSupply = frxUSD.totalSupply();
        uint256 previewWithdraw = frxUSDCustodian.previewWithdraw(100e6);
        frxUSDCustodian.withdraw(100e6, address(whale), address(whale));
        uint256 amountOut = USTB.balanceOf(address(whale)) - balanceUSTB;
        uint256 amountIn = balanceFrxUSD - frxUSD.balanceOf(address(whale));
        assertApproxEqAbs(amountOut, expectedOut, 1, "Amount out should be correct");
        assertApproxEqAbs(amountIn / 1e14, expectedIn / 1e14, 1, "Amount in should be correct");
        assertApproxEqAbs(amountIn, previewWithdraw, 1, "Amount out should be equal to preview");
        assertApproxEqAbs(totalSupply - amountIn, frxUSD.totalSupply(), 1, "totalSupply incorrect");
        assertApproxEqAbs(frxUSDCustodian.frxUSDMinted(), 1100e18 - amountIn, 1, "frxUSDMinted incorrect");
        vm.stopPrank();
    }

    function test_mintCap() public {
        defaultSetup(USTB);
        address whale = 0x5138D77d51dC57983e5A653CeA6e1C1aa9750A39;
        vm.startPrank(whale);

        USTB.approve(address(frxUSDCustodian), 1_000_000e18);
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
        defaultSetup(USTB);
        address whale = 0x5138D77d51dC57983e5A653CeA6e1C1aa9750A39;
        vm.startPrank(frxUSDCustodian.owner());
        frxUSD.addMinter(frxUSDCustodian.owner());
        frxUSD.minter_mint(address(whale), 1_000_000e18);
        vm.stopPrank();
        vm.startPrank(whale);

        USTB.approve(address(frxUSDCustodian), 1_000_000e18);
        frxUSD.approve(address(frxUSDCustodian), 1_000_000e18);
        frxUSDCustodian.deposit(100e6, address(whale));

        uint256 maxWithdraw = frxUSDCustodian.maxWithdraw(whale);
        assertApproxEqAbs(
            maxWithdraw,
            USTB.balanceOf(address(frxUSDCustodian)),
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
        frxUSDCustodian.deposit(100e6, address(whale));

        // Withdrawing should work again
        frxUSDCustodian.withdraw(frxUSDCustodian.maxWithdraw(whale) - 1, address(whale), address(whale));

        vm.stopPrank();
    }

    function test_ownerFunctionality() public {
        defaultSetup(USTB);
        address whale = 0x5138D77d51dC57983e5A653CeA6e1C1aa9750A39;
        vm.startPrank(whale);

        USTB.approve(address(frxUSDCustodian), 1_000_000e18);
        frxUSD.approve(address(frxUSDCustodian), 1_000_000e18);

        // Mint the cap
        frxUSDCustodian.mint(frxUSDCustodian.maxMint(whale), address(whale));

        vm.expectRevert(); // Revert when not owner
        frxUSDCustodian.setMintCap(20_000e18);

        vm.expectRevert(); // Revert when not owner
        frxUSDCustodian.setMintRedeemFee(0.02e18, 0.03e18);

        vm.expectRevert(); // Revert when not owner
        frxUSDCustodian.recoverERC20(address(USTB), 100e6);
        vm.stopPrank();

        vm.startPrank(frxUSDCustodian.owner());
        frxUSDCustodian.setMintCap(20_000e18);
        assertEq(frxUSDCustodian.mintCap(), 20_000e18, "mintCap should be set");

        frxUSDCustodian.setMintRedeemFee(0.02e18, 0.03e18);
        assertEq(frxUSDCustodian.mintFee(), 0.02e18, "fee should be set");
        assertEq(frxUSDCustodian.redeemFee(), 0.03e18, "fee should be set");

        uint256 balance = USTB.balanceOf(frxUSDCustodian.owner());
        frxUSDCustodian.recoverERC20(address(USTB), 100e6);
        assertEq(USTB.balanceOf(frxUSDCustodian.owner()), balance + 100e6, "ERC20 should be recovered");
        vm.stopPrank();

        vm.startPrank(whale);
        // Mint is possible again
        frxUSDCustodian.mint(1000e18, address(whale));
        vm.stopPrank();
    }

    function test_noFeeRounding() public {
        defaultSetup(USTB);
        address whale = 0x5138D77d51dC57983e5A653CeA6e1C1aa9750A39;
        vm.startPrank(frxUSDCustodian.owner());
        frxUSDCustodian.setMintRedeemFee(0, 0);
        vm.stopPrank();
        vm.startPrank(whale);
        USTB.approve(address(frxUSDCustodian), 1_000_000e18);
        frxUSD.approve(address(frxUSDCustodian), 1_000_000e18);
        frxUSDCustodian.mint(5000e18, address(whale));
        if (true) {
            // mint/redeem
            uint256 amount = 10e18;
            for (uint256 i = 0; i < 10; i++) {
                uint256 balance1 = USTB.balanceOf(whale);
                frxUSDCustodian.mint(amount, address(whale));
                frxUSDCustodian.redeem(amount, address(whale), address(whale));
                uint256 balance2 = USTB.balanceOf(whale);
                require(balance2 <= balance1 && balance1 - balance2 <= 1, "No profit should be made");
                amount = amount / 3;
            }
        }
        if (true) {
            // mint/withdraw
            uint256 amount = 10e18;
            for (uint256 i = 0; i < 10; i++) {
                uint256 balance1 = USTB.balanceOf(whale);
                frxUSDCustodian.mint(amount, address(whale));
                uint256 withdrawAmount = frxUSDCustodian.previewRedeem(amount);
                frxUSDCustodian.withdraw(withdrawAmount, address(whale), address(whale));
                uint256 balance2 = USTB.balanceOf(whale);
                require(balance2 <= balance1 && balance1 - balance2 <= 1, "No profit should be made");
                amount = amount / 3;
            }
        }
        if (true) {
            // deposit/withdraw
            uint256 amount = 10e6;
            for (uint256 i = 0; i < 10; i++) {
                uint256 balance1 = USTB.balanceOf(whale);
                frxUSDCustodian.deposit(amount, address(whale));
                frxUSDCustodian.withdraw(amount, address(whale), address(whale));
                uint256 balance2 = USTB.balanceOf(whale);
                require(balance2 <= balance1 && balance1 - balance2 <= 1, "No profit should be made");
                amount = amount / 3;
            }
        }
        if (true) {
            // deposit/redeem
            uint256 amount = 10e6;
            for (uint256 i = 0; i < 10; i++) {
                uint256 balance1 = USTB.balanceOf(whale);
                frxUSDCustodian.deposit(amount, address(whale));
                uint256 redeemAmount = frxUSDCustodian.previewWithdraw(amount);
                frxUSDCustodian.redeem(redeemAmount, address(whale), address(whale));
                uint256 balance2 = USTB.balanceOf(whale);
                require(balance2 <= balance1 && balance1 - balance2 <= 1, "No profit should be made");
                amount = amount / 3;
            }
        }
    }
}

interface AllowList {
    function setEntityIdForAddress(uint256 entityId, address addr) external;
}
