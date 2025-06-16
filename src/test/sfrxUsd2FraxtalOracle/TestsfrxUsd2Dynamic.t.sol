// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import { StakedFrxUSD2, IERC20 } from "src/contracts/StakedFrxUSD2.sol";
import { SfrxUsd2OracleImplementation } from "src/contracts/SfrxUsd2OracleImplementation.sol";
import "frax-std/FraxTest.sol";

contract TestSrxUsd2OracleDynamic is FraxTest {
    uint256 ORACLE_PRECISION;
    StakedFrxUSD2 sfrxusd;
    IERC20 frxusd = IERC20(0xFc00000000000000000000000000000000000001);
    SfrxUsd2OracleImplementation instance;
    address public badActor = address(0xBADBEEF);
    address carl = address(0xca71);

    function setUp() public {
        vm.createSelectFork(vm.envString("FRAXTAL_MAINNET_URL"));

        /// @notice Simplified setup, requires HF

        // deploy mock sfrxUSD contract
        sfrxusd = new StakedFrxUSD2(frxusd, "sfrxUSD", "sfrxUSD", address(this));
        uint256[2] memory ppsInfo = [uint256(1_137_989_069_558_259_178), uint256(4_431_822_119)];
        sfrxusd.initialize("sfrxUSD", "sfrxUSD", address(this), ppsInfo);
        instance = new SfrxUsd2OracleImplementation(address(this));
        instance.setAllPricingParams(1_137_989_069_558_259_178, 4_431_822_119, block.timestamp);

        // instance.initialize(address(this));
        vm.etch(0x1B680F4385f24420D264D78cab7C58365ED3F1FF, address(instance).code);
        instance = SfrxUsd2OracleImplementation(0x1B680F4385f24420D264D78cab7C58365ED3F1FF);
        instance.initialize(address(this));
        instance.setAllPricingParams(1_137_989_069_558_259_178, 4_431_822_119, block.timestamp);
    }

    function test_deployment() public {
        console.log(address(sfrxusd));
        console.log("Initial Price Per Share: ", sfrxusd.pricePerShare());
        console.log("Initial Price Per Share from oracle: ", instance.pricePerShare());
        console.log("Expected from contract: ", sfrxusd.previewPricePerShareFuture(block.timestamp + 3650 days));
        for (uint256 i; i < 3650; ++i) {
            vm.warp(block.timestamp + 1 days);
            sfrxusd.sync();
            // instance.updateLastSync(block.timestamp);
        }
        // vm.warp(block.timestamp + 365 days);

        _swaps({ shouldRevert: false });
        console.log("Final Price Per Share: ", sfrxusd.pricePerShare());
        console.log("Final Price Per Share from oracle: ", instance.pricePerShare());
    }

    function test_cannot_reinit() public {
        vm.expectRevert(bytes4(keccak256("AlreadyInit()")));
        instance.initialize(address(badActor));
    }

    function test_nonAllowed_cannot_update_priceInfo() public {
        vm.prank(badActor);
        vm.expectRevert(bytes4(keccak256("NotAllowed()")));
        instance.setAllPricingParams(20_000e18, 1e18, 0);
    }

    function test_nonAllowed_cannot_setPricePerShareIncPerSecond() public {
        vm.prank(badActor);
        vm.expectRevert(bytes4(keccak256("NotAllowed()")));
        instance.setPricePerShareIncPerSecond(block.timestamp);
    }

    function test_nonAllowed_cannot_setPricePerShareStored() public {
        vm.prank(badActor);
        vm.expectRevert(bytes4(keccak256("NotAllowed()")));
        instance.setPricePerShareStored(block.timestamp);
    }

    function test_previewRateWorks(uint32 value) public {
        uint256 startContract = sfrxusd.previewPricePerShare();
        uint256 startOracle = instance.previewPricePerShare();
        console.log("startOracle: ", startOracle, "startContract: ", startContract);
        assertEq({ a: startOracle, b: startContract, err: "// THEN: Start prices are not the same" });

        uint256 timeToCheck = block.timestamp + value;
        uint256 futureValueContract = sfrxusd.previewPricePerShareFuture(timeToCheck);
        uint256 futureValueOracle = instance.previewPricePerShareFuture(timeToCheck);
        assertEq({ a: futureValueContract, b: futureValueOracle, err: "// THEN: Projected prices are not the same" });
    }

    function test_fuzz_exact_same_rate_no_sync(uint32 timeDelta) public {
        uint256 startContract = sfrxusd.previewPricePerShare();
        uint256 startOracle = instance.previewPricePerShare();
        console.log("startOracle: ", startOracle, "startContract: ", startContract);
        assertEq({ a: startOracle, b: startContract, err: "// THEN: Start prices are not the same" });

        vm.warp(block.timestamp + timeDelta);
        uint256 endContract = sfrxusd.previewPricePerShare();
        uint256 endOracle = instance.previewPricePerShare();
        assertEq({ a: endContract, b: endOracle, err: "// THEN: future prices are not the same" });
    }

    function test_fuzz_small_diff_when_sync(uint32 value) public {
        uint256 startContract = sfrxusd.previewPricePerShare();
        uint256 startOracle = instance.previewPricePerShare();
        console.log("startOracle: ", startOracle, "startContract: ", startContract);
        assertEq({ a: startOracle, b: startContract, err: "// THEN: Start prices are not the same" });

        uint256 numDays = value / 1 days;
        for (uint256 i; i < numDays; ++i) {
            vm.warp(block.timestamp + 1 days);
            sfrxusd.sync();
        }

        uint256 endContract = sfrxusd.previewPricePerShare();
        uint256 endOracle = instance.previewPricePerShare();
        assertApproxEqRel(endOracle, endContract, 0.0000000000001e18);
    }

    function test_calculateForGiven() public {
        console.log(sfrxusd.calcPPSIPSForGivenAPY(1.15e18));
    }

    function _swaps(bool shouldRevert) internal {
        IERC4626Vault mintRedeemer = IERC4626Vault(0xBFc4D34Db83553725eC6c768da71D2D9c1456B55);
        deal(address(frxusd), carl, 100e18);

        vm.startPrank(carl);
        frxusd.approve(address(mintRedeemer), 100e18);
        if (shouldRevert) vm.expectRevert();
        uint256 out = mintRedeemer.deposit(100e18, carl);
        // console.log("Amount out: ", out);
    }
}

interface IERC4626Vault {
    function deposit(uint256 assetIn, address receiver) external returns (uint256);

    function redeem(uint256 sharesIn, address receiver, address owner) external returns (uint256);
}
