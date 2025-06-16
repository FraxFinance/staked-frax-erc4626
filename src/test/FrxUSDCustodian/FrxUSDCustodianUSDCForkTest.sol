// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FrxUSD } from "../../contracts/FrxUSD.sol";
import { FrxUSDCustodian } from "../../contracts/FrxUSDCustodian.sol";
import { FrxUSDCustodianFactory } from "../../contracts/FrxUSDCustodianFactory.sol";
import "../../Constants.sol" as Constants;

contract FrxUSDCustodianUSDCForkTest is FraxTest {
    address constant frxUSDCustodian = 0x4F95C5bA0C7c69FB2f9340E190cCeE890B3bd87c;
    address constant FRXUSD = 0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29;
    IERC20 public USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    function test_FrxUSDCustodian() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 22_197_561);
        address whale = 0x5E583B6a1686f7Bc09A6bBa66E852A7C80d36F00;
        FrxUSDCustodian custContract = FrxUSDCustodian(frxUSDCustodian);
        vm.startPrank(whale);
        USDC.approve(frxUSDCustodian, 100_000e6);
        vm.expectRevert(); // Not yet minter
        custContract.mint(100e18, whale);
        vm.stopPrank();

        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        FrxUSD(FRXUSD).addMinter(frxUSDCustodian);
        vm.stopPrank();

        vm.startPrank(whale);
        uint256 usdcBalance = USDC.balanceOf(whale);
        uint256 frxUSDBalance = IERC20(FRXUSD).balanceOf(whale);
        custContract.mint(100e18, whale);
        custContract.mint(99_900e18, whale);
        assertEq(USDC.balanceOf(whale), usdcBalance - 100e6 - 99_900e6, "USDC balance mismatch after minting");
        assertEq(
            IERC20(FRXUSD).balanceOf(whale),
            frxUSDBalance + 100e18 + 99_900e18,
            "FRXUSD balance mismatch after minting"
        );
        vm.expectRevert(); // At mint cap
        custContract.mint(1e18, whale);
        IERC20(FRXUSD).approve(frxUSDCustodian, 100_000e18);
        usdcBalance = USDC.balanceOf(whale);
        frxUSDBalance = IERC20(FRXUSD).balanceOf(whale);
        custContract.redeem(100_000e18, whale, whale);
        assertEq(
            USDC.balanceOf(whale),
            usdcBalance + (100_000e6 * 9999) / 10_000,
            "USDC balance mismatch after redeeming"
        );
        assertEq(
            IERC20(FRXUSD).balanceOf(whale),
            frxUSDBalance - 100_000e18,
            "FRXUSD balance mismatch after redeeming"
        );
        vm.stopPrank();
    }
}
