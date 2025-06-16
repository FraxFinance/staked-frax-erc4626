// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FrxUSDMigrator } from "../../contracts/FrxUSDMigrator.sol";
import { StakedFrax } from "../../contracts/StakedFrax.sol";
import { StakedFrxUSD } from "../../contracts/StakedFrxUSD.sol";
import { FrxUSD } from "../../contracts/FrxUSD.sol";
import { FrxUSDCustodian } from "../../contracts/FrxUSDCustodian.sol";
import "../../Constants.sol" as Constants;

contract FrxUSDMigratorTest is FraxTest {
    FrxUSDMigrator migrator;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_686_820);
        migrator = new FrxUSDMigrator();
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        FrxUSD(address(migrator.frxUSD())).addMinter(address(migrator.frxUSDCustodian()));
        migrator.frax().approve(address(migrator.frxUSDCustodian()), 1000e18);
        migrator.frxUSDCustodian().mint(1000e18, Constants.Mainnet.FRAX_ERC20_OWNER);
        vm.stopPrank();
    }

    function test_migrate() public {
        address whale = 0x34C0bD5877A5Ee7099D0f5688D65F4bB9158BDE2;
        migrationTest(whale, address(migrator.sFRAX()), address(migrator.frax()), 1000e18);
        migrationTest(whale, address(migrator.sFRAX()), address(migrator.frxUSD()), 1000e18);
        migrationTest(whale, address(migrator.sFRAX()), address(migrator.sfrxUSD()), 1000e18);
        migrationTest(whale, address(migrator.frax()), address(migrator.frxUSD()), 1000e18);
        migrationTest(whale, address(migrator.frax()), address(migrator.sfrxUSD()), 1000e18);
        migrationTest(whale, address(migrator.frxUSD()), address(migrator.sfrxUSD()), 1000e18);
    }

    function migrationTest(address user, address tokenIn, address tokenOut, uint256 amount) public {
        vm.startPrank(user);
        uint256 balTokenIn = IERC20(tokenIn).balanceOf(user);
        uint256 balTokenOut = IERC20(tokenOut).balanceOf(user);
        IERC20(tokenIn).approve(address(migrator), amount);
        uint256 amountOut = migrator.migrate(tokenIn, tokenOut, amount);
        require(amountOut > 0, "Amount out should be greater than 0");
        uint256 balTokenIn2 = IERC20(tokenIn).balanceOf(user);
        uint256 balTokenOut2 = IERC20(tokenOut).balanceOf(user);
        assertEq(balTokenIn - amount, balTokenIn2, "In balance should have decreased by amount");
        assertEq(balTokenOut + amountOut, balTokenOut2, "Out balance should have increased by amountOut");
        vm.stopPrank();
    }

    function test_unmigrate() public {
        address whale = 0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27;
        unmigrationTest(whale, address(migrator.sfrxUSD()), address(migrator.frxUSD()), 100e18);
        unmigrationTest(whale, address(migrator.sfrxUSD()), address(migrator.frax()), 100e18);
        unmigrationTest(whale, address(migrator.sfrxUSD()), address(migrator.sFRAX()), 100e18);
        unmigrationTest(whale, address(migrator.frxUSD()), address(migrator.frax()), 100e18);
        unmigrationTest(whale, address(migrator.frxUSD()), address(migrator.sFRAX()), 100e18);
        unmigrationTest(whale, address(migrator.frax()), address(migrator.sFRAX()), 100e18);
    }

    function unmigrationTest(address user, address tokenIn, address tokenOut, uint256 amount) public {
        vm.startPrank(user);
        uint256 balTokenIn = IERC20(tokenIn).balanceOf(user);
        uint256 balTokenOut = IERC20(tokenOut).balanceOf(user);
        IERC20(tokenIn).approve(address(migrator), amount);
        uint256 amountOut = migrator.unmigrate(tokenIn, tokenOut, amount);
        require(amountOut > 0, "Amount out should be greater than 0");
        uint256 balTokenIn2 = IERC20(tokenIn).balanceOf(user);
        uint256 balTokenOut2 = IERC20(tokenOut).balanceOf(user);
        assertEq(balTokenIn - amount, balTokenIn2, "In balance should have decreased by amount");
        assertEq(balTokenOut + amountOut, balTokenOut2, "Out balance should have increased by amountOut");
        vm.stopPrank();
    }
}
