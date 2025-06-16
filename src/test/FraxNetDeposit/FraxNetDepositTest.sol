// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FraxNetDeposit } from "../../contracts/FraxNetDeposit.sol";
import { FraxNetDepositFactory } from "../../contracts/FraxNetDepositFactory.sol";
import { IFrxUSDCustodian } from "../../contracts/interfaces/IFrxUSDCustodian.sol";
import { FrxUSDCustodianFactory } from "../../contracts/FrxUSDCustodianFactory.sol";
import { IRemoteHop } from "../../contracts/interfaces/IRemoteHop.sol";
import { FrxUSD } from "../../contracts/FrxUSD.sol";

contract FraxNetDepositTest is FraxTest {
    FrxUSD public constant frxUSD = FrxUSD(0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    FraxNetDepositFactory factory;
    IFrxUSDCustodian frxUSDCustodian;
    IRemoteHop remoteHop;

    event SendOFT(address oft, address indexed sender, uint32 indexed dstEid, bytes32 indexed to, uint256 amountLD);

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 22_217_252);
        frxUSDCustodian = IFrxUSDCustodian(0x4F95C5bA0C7c69FB2f9340E190cCeE890B3bd87c);
        remoteHop = IRemoteHop(0x4DDDc830c7C9a0CfcB941416B92D75F12423bc37);
        factory = new FraxNetDepositFactory(frxUSDCustodian, remoteHop);
    }

    function test_createFraxNetDeposit() public {
        address predictedAddress = factory.getDeploymentAddress(30_101, bytes32(uint256(0xb0b)));
        FraxNetDeposit fraxNetDeposit = factory.createFraxNetDeposit(30_101, bytes32(uint256(0xb0b)));
        assertEq(address(fraxNetDeposit), predictedAddress);
        assertEq(address(factory.frxUSDCustodian()), address(frxUSDCustodian));
        assertEq(address(factory.remoteHop()), address(remoteHop));
        assertEq(fraxNetDeposit.targetEid(), 30_101);
        assertEq(fraxNetDeposit.targetAddress(), bytes32(uint256(0xb0b)));
        assertEq(address(fraxNetDeposit.factory()), address(factory));
    }

    function test_FraxNetDeposit_Ethereum() public {
        FraxNetDeposit fraxNetDeposit = factory.createFraxNetDeposit(30_101, bytes32(uint256(0xb0b)));
        vm.startPrank(address(0x28C6c06298d514Db089934071355E5743bf21d60));
        USDC.transfer(address(fraxNetDeposit), 100e6);
        vm.stopPrank();
        fraxNetDeposit.process{ value: 0 }(100e6);
        assertEq(frxUSD.balanceOf(address(fraxNetDeposit)), 0);
        assertEq(frxUSD.balanceOf(address(uint160(uint256(bytes32(uint256(0xb0b)))))), 100e18);
    }

    function test_FraxNetDeposit_Arbitrum() public {
        FraxNetDeposit fraxNetDeposit = factory.createFraxNetDeposit(30_110, bytes32(uint256(0xb0b)));
        vm.startPrank(address(0x28C6c06298d514Db089934071355E5743bf21d60));
        USDC.transfer(address(fraxNetDeposit), 100e6);
        vm.stopPrank();
        IRemoteHop.MessagingFee memory fee = fraxNetDeposit.quote(100e6);
        vm.expectEmit();
        emit SendOFT(
            0x566a6442A5A6e9895B9dCA97cC7879D632c6e4B0,
            address(fraxNetDeposit),
            30_110,
            bytes32(uint256(0xb0b)),
            100e18
        );
        fraxNetDeposit.process{ value: fee.nativeFee }(100e6);
        assertEq(frxUSD.balanceOf(address(fraxNetDeposit)), 0);
        assertEq(frxUSD.balanceOf(address(uint160(uint256(bytes32(uint256(0xb0b)))))), 0);
    }

    function test_FraxNetDeposit_Fraxtal() public {
        FraxNetDeposit fraxNetDeposit = factory.createFraxNetDeposit(30_255, bytes32(uint256(0xb0b)));
        vm.startPrank(address(0x28C6c06298d514Db089934071355E5743bf21d60));
        USDC.transfer(address(fraxNetDeposit), 100e6);
        vm.stopPrank();
        IRemoteHop.MessagingFee memory fee = remoteHop.quote(
            0x566a6442A5A6e9895B9dCA97cC7879D632c6e4B0,
            30_255,
            bytes32(uint256(0xb0b)),
            100e18
        );
        vm.expectEmit();
        emit SendOFT(
            0x566a6442A5A6e9895B9dCA97cC7879D632c6e4B0,
            address(fraxNetDeposit),
            30_255,
            bytes32(uint256(0xb0b)),
            100e18
        );
        fraxNetDeposit.process{ value: fee.nativeFee }(100e6);
        assertEq(frxUSD.balanceOf(address(fraxNetDeposit)), 0);
        assertEq(frxUSD.balanceOf(address(uint160(uint256(bytes32(uint256(0xb0b)))))), 0);
    }

    function test_FraxNetDeposit_recoverERC20() public {
        FraxNetDeposit fraxNetDeposit = factory.createFraxNetDeposit(30_255, bytes32(uint256(0xb0b)));
        vm.startPrank(address(0x28C6c06298d514Db089934071355E5743bf21d60));
        USDC.transfer(address(fraxNetDeposit), 100e6);
        vm.stopPrank();
        uint256 balanceBefore = USDC.balanceOf(address(this));
        factory.recoverERC20(address(USDC), 100e6, fraxNetDeposit, address(this));
        uint256 balanceAfter = USDC.balanceOf(address(this));
        assertEq(balanceAfter - balanceBefore, 100e6);
    }

    function test_FraxNetDeposit_operator() public {
        payable(address(0xb0b)).transfer(0.1e18);
        FraxNetDeposit fraxNetDeposit = factory.createFraxNetDeposit(30_255, bytes32(uint256(0xb0b)));
        vm.startPrank(address(0x28C6c06298d514Db089934071355E5743bf21d60));
        USDC.transfer(address(fraxNetDeposit), 100e6);
        vm.stopPrank();
        IRemoteHop.MessagingFee memory fee = fraxNetDeposit.quote(100e6);
        vm.prank(address(0xb0b));
        vm.expectRevert();
        fraxNetDeposit.process{ value: fee.nativeFee }(100e6);
        factory.setOperator(address(0xb0b), true);
        vm.prank(address(0xb0b));
        fraxNetDeposit.process{ value: fee.nativeFee }(100e6);
    }

    function test_FraxNetDeposit_setRemoteHop() public {
        payable(address(0xb0b)).transfer(0.1e18);
        FraxNetDeposit fraxNetDeposit = factory.createFraxNetDeposit(30_255, bytes32(uint256(0xb0b)));
        vm.startPrank(address(0x28C6c06298d514Db089934071355E5743bf21d60));
        USDC.transfer(address(fraxNetDeposit), 100e6);
        vm.stopPrank();
        IRemoteHop.MessagingFee memory fee = fraxNetDeposit.quote(100e6);
        factory.setRemoteHop(IRemoteHop(address(0xB0b)));
        vm.expectRevert();
        fraxNetDeposit.process{ value: fee.nativeFee }(100e6);
        factory.setRemoteHop(remoteHop);
        fraxNetDeposit.process{ value: fee.nativeFee }(100e6);
    }

    function test_FraxNetDeposit_setCustodian() public {
        payable(address(0xb0b)).transfer(0.1e18);
        FraxNetDeposit fraxNetDeposit = factory.createFraxNetDeposit(30_255, bytes32(uint256(0xb0b)));
        vm.startPrank(address(0x28C6c06298d514Db089934071355E5743bf21d60));
        USDC.transfer(address(fraxNetDeposit), 100e6);
        vm.stopPrank();
        IRemoteHop.MessagingFee memory fee = fraxNetDeposit.quote(100e6);
        factory.setFrxUSDCustodian(IFrxUSDCustodian(address(0xB0b)));
        vm.expectRevert();
        fraxNetDeposit.process{ value: fee.nativeFee }(100e6);
        factory.setFrxUSDCustodian(frxUSDCustodian);
        fraxNetDeposit.process{ value: fee.nativeFee }(100e6);
    }

    function test_FraxNetDepoist_InsufficientBalance() public {
        FraxNetDeposit fraxNetDeposit = factory.createFraxNetDeposit(30_255, bytes32(uint256(0xb0b)));
        vm.startPrank(address(0x28C6c06298d514Db089934071355E5743bf21d60));
        USDC.transfer(address(fraxNetDeposit), 100e6);
        vm.stopPrank();
        vm.expectRevert();
        fraxNetDeposit.process{ value: 0 }(200e6);
    }
}
