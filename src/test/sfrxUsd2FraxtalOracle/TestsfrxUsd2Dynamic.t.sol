// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import { StakedFrxUSD2, IERC20 } from "src/contracts/StakedFrxUSD2.sol";
import { SfrxUsd2OracleImplementation } from "src/contracts/SfrxUsd2OracleImplementation.sol";
import "frax-std/FraxTest.sol";

contract TestSrxUsd2OracleDynamic is FraxTest {
    uint256 ORACLE_PRECISION;
    StakedFrxUSD2 sfrxusd;
    IERC20 frxusd = IERC20(0xFc00000000000000000000000000000000000001);

    /// @notice This is the implementation
    SfrxUsd2OracleImplementation instanceImpl;
    /// @notice This is the proxy
    SfrxUsd2OracleImplementation instance;

    /// @notice Addresses for testing
    address public badActor = address(0xBADBEEF);
    address carl = address(0xca71);

    /// @notice Simplified setup, requires HF
    function setUp() public {
        vm.createSelectFork(vm.envString("FRAXTAL_RPC_URL"));

        uint256 currentOraclePPS = SfrxUsd2OracleImplementation(0x1B680F4385f24420D264D78cab7C58365ED3F1FF)
            .pricePerShare();

        /// @dev deploy mock sfrxUSD contract, this contract will be used to ensure that there is
        ///      rate equivalency between the sfrxUSD implementation on mainnet and the oracle we will
        ///      be deploying on fraxtal
        sfrxusd = new StakedFrxUSD2(frxusd, "sfrxUSD", "sfrxUSD", address(this));
        uint256[2] memory ppsInfo = [uint256(currentOraclePPS), uint256(4_431_822_119)];

        // vm.etch(0x0000B5a97bCD002981200222Eb7FA13e8024E116, address(sfrxusd).code);
        // sfrxusd = StakedFrxUSD2(0xfc00000000000000000000000000000000000008);

        /// @notice This slot on the sfrxUSD contracts contains the was initialized value,
        ///         as well as the owner, setting this value to
        ///         `bytes32(uint256(uint160(address(this))))` implicitly overrides the value
        ///         of `initialized` and allows us to reinitialize the implementation
        /// @dev This is a simplification of the sfrxUSD upgrade and will not occur in prod
        bytes32 value = vm.load(address(sfrxusd), bytes32(uint256(18)));
        bytes32 toSet = bytes32(uint256(uint160(address(this))));
        // console.logBytes32(value);
        // console.logBytes32(toSet);
        vm.store(address(sfrxusd), bytes32(uint256(18)), toSet);

        sfrxusd.initialize("sfrxUSD", "sfrxUSD", address(this), ppsInfo);

        instanceImpl = new SfrxUsd2OracleImplementation(address(this));
        // instanceImpl.setAllPricingParams(currentOraclePPS, 4_431_822_119, block.timestamp);

        /// @notice Simplified setup, requires HF
        /// @notice We begin by setting the code at the oracle address to that of a proxy,
        ///         eg: frxUSD, we will then override the

        // 1) Etch the current oracle code to a different address
        vm.etch(address(0xfcfcfcfc0de), address(0x1B680F4385f24420D264D78cab7C58365ED3F1FF).code);

        // 2) Set the oracle address's code to that of a EIP 1967 transparent proxy
        vm.etch(0x1B680F4385f24420D264D78cab7C58365ED3F1FF, address(0xFc00000000000000000000000000000000000001).code);

        // 3) Set the EIP1967 slot values on the old oracle which is now a proxy
        bytes32 adminSlotValue = vm.load(
            address(0xFc00000000000000000000000000000000000001),
            bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1) // FrxUSD
        );
        vm.store(
            0x1B680F4385f24420D264D78cab7C58365ED3F1FF,
            bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1),
            adminSlotValue
        );
        vm.store(
            0x1B680F4385f24420D264D78cab7C58365ED3F1FF,
            bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1),
            bytes32(uint256(uint160(address(0xfcfcfcfc0de))))
        );

        instance = SfrxUsd2OracleImplementation(0x1B680F4385f24420D264D78cab7C58365ED3F1FF);

        // instance = SfrxUsd2OracleImplementation(0x1B680F4385f24420D264D78cab7C58365ED3F1FF);
        // instance.initialize(
        //     address(this),
        //     1_137_989_069_558_259_178,
        //     4_431_822_119,
        //     block.timestamp
        // );
        // instance.setAllPricingParams(1_137_989_069_558_259_178, 4_431_822_119, block.timestamp);
    }

    function test_values() public {
        console.log("AQUI");
        bytes32 adminSlotValue = vm.load(
            address(0xFc00000000000000000000000000000000000001),
            bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
        );
        // bytes32 implSlotValue =
        console.logBytes32(adminSlotValue);

        uint256 value = SfrxUsd2OracleImplementation(0x1B680F4385f24420D264D78cab7C58365ED3F1FF).pricePerShare();
        console.log("Value: ", value);
    }

    function test_upgrade() public {
        _upgradeProxyOracle();
    }

    modifier doProxyUpgrade() {
        _upgradeProxyOracle();
        _;
    }

    function _upgradeProxyOracle() public {
        IProxyAdmin proxyAdmin = IProxyAdmin(0xfC0000000000000000000000000000000000000a);

        // Craft the initialization call
        uint256 ppsValueStart = SfrxUsd2OracleImplementation(0x1B680F4385f24420D264D78cab7C58365ED3F1FF)
            .pricePerShare();

        console.log("PPS prior to hand off: ", ppsValueStart);
        bytes memory _data = abi.encodeWithSelector(
            SfrxUsd2OracleImplementation.initialize.selector,
            proxyAdmin.owner(),
            ppsValueStart,
            uint256(4_431_822_119),
            block.timestamp
        );

        vm.prank(proxyAdmin.owner());
        proxyAdmin.upgradeAndCall(address(instance), address(instanceImpl), _data);

        uint256 ppsPost = instance.pricePerShare();
        console.log("The PPS post hand off: ", ppsPost);
        // Assert that the value reported has not changed post upgrade
        assertEq({ a: ppsPost, b: ppsValueStart, err: "// THEN: Oracle value changed during the upgrade" });

        /// @notice address(this) is granted allowed
        vm.prank(proxyAdmin.owner());
        instance.setAllowed(address(this), true);
    }

    function test_deployment() public doProxyUpgrade {
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

    function test_cannot_reinit() public doProxyUpgrade {
        vm.expectRevert(bytes4(keccak256("AlreadyInit()")));
        instance.initialize(address(badActor), 1_137_989_069_558_259_178, 4_431_822_119, block.timestamp);
    }

    function test_nonAllowed_cannot_update_priceInfo() public doProxyUpgrade {
        vm.prank(badActor);
        vm.expectRevert(bytes4(keccak256("NotAllowed()")));
        instance.setAllPricingParams(20_000e18, 1e18, 0);
    }

    function test_nonAllowed_cannot_setPricePerShareIncPerSecond() public doProxyUpgrade {
        vm.prank(badActor);
        vm.expectRevert(bytes4(keccak256("NotAllowed()")));
        instance.setPricePerShareIncPerSecond(block.timestamp);
    }

    function test_nonAllowed_cannot_setPricePerShareStored() public doProxyUpgrade {
        vm.prank(badActor);
        vm.expectRevert(bytes4(keccak256("NotAllowed()")));
        instance.setPricePerShareStored(block.timestamp);
    }

    function test_setPricePerShareIncPerSecond_works() public doProxyUpgrade {
        vm.warp(block.timestamp + 10 days);
        uint256 priceStartSfrxUsd = sfrxusd.pricePerShare();
        uint256 priceStartOracle = instance.pricePerShare();

        console.log("priceStartSfrxUsd, priceStartOracle: ", priceStartSfrxUsd, priceStartOracle);
        assertEq({ a: priceStartSfrxUsd, b: priceStartOracle, err: "// THEN: Price end not as expected" });

        sfrxusd.setPricePerShareIncPerSecond(4_431_822_119 * 2);
        instance.setPricePerShareIncPerSecond(4_431_822_119 * 2);

        vm.warp(block.timestamp + 10 days);
        uint256 priceEndSfrxUsd = sfrxusd.pricePerShare();
        uint256 priceEndOracle = instance.pricePerShare();

        console.log("priceEndSfrxUsd, priceEndOracle: ", priceEndSfrxUsd, priceEndOracle);
        assertEq({ a: priceEndOracle, b: priceEndSfrxUsd, err: "// THEN: Price end not as expected" });
    }

    function test_fuzz_setPricePerShareIncPerSecond_parity(
        uint32 timeDelta,
        uint32 ratePerSecond
    ) public doProxyUpgrade {
        vm.warp(block.timestamp + 10 days);
        uint256 priceStartSfrxUsd = sfrxusd.pricePerShare();
        uint256 priceStartOracle = instance.pricePerShare();

        console.log("priceStartSfrxUsd, priceStartOracle: ", priceStartSfrxUsd, priceStartOracle);
        assertEq({ a: priceStartSfrxUsd, b: priceStartOracle, err: "// THEN: Price end not as expected" });

        sfrxusd.setPricePerShareIncPerSecond(ratePerSecond);
        instance.setPricePerShareIncPerSecond(ratePerSecond);

        vm.warp(block.timestamp + timeDelta);
        uint256 priceEndSfrxUsd = sfrxusd.pricePerShare();
        uint256 priceEndOracle = instance.pricePerShare();

        console.log("priceEndSfrxUsd, priceEndOracle: ", priceEndSfrxUsd, priceEndOracle);
        assertEq({ a: priceEndOracle, b: priceEndSfrxUsd, err: "// THEN: Price end not as expected" });
    }

    function test_setPricePerShareStored_works() public doProxyUpgrade {
        vm.warp(block.timestamp + 10 days);
        uint256 priceStartSfrxUsd = sfrxusd.pricePerShare();
        uint256 priceStartOracle = instance.pricePerShare();

        console.log("priceStartSfrxUsd, priceStartOracle: ", priceStartSfrxUsd, priceStartOracle);
        assertEq({ a: priceStartSfrxUsd, b: priceStartOracle, err: "// THEN: Price end not as expected" });

        sfrxusd.setPricePerShareStored(2e18);
        instance.setPricePerShareStored(2e18);

        vm.warp(block.timestamp + 10 days);
        uint256 priceEndSfrxUsd = sfrxusd.pricePerShare();
        uint256 priceEndOracle = instance.pricePerShare();

        console.log("priceEndSfrxUsd, priceEndOracle: ", priceEndSfrxUsd, priceEndOracle);
        assertEq({ a: priceEndOracle, b: priceEndSfrxUsd, err: "// THEN: Price end not as expected" });
    }

    function test_fuzz_setPricePerShareStored_parity(uint32 timeDelta, uint128 newPPS) public doProxyUpgrade {
        vm.warp(block.timestamp + 10 days);
        uint256 priceStartSfrxUsd = sfrxusd.pricePerShare();
        uint256 priceStartOracle = instance.pricePerShare();

        console.log("priceStartSfrxUsd, priceStartOracle: ", priceStartSfrxUsd, priceStartOracle);
        assertEq({ a: priceStartSfrxUsd, b: priceStartOracle, err: "// THEN: Price end not as expected" });

        sfrxusd.setPricePerShareStored(newPPS);
        instance.setPricePerShareStored(newPPS);

        vm.warp(block.timestamp + timeDelta);
        uint256 priceEndSfrxUsd = sfrxusd.pricePerShare();
        uint256 priceEndOracle = instance.pricePerShare();

        console.log("priceEndSfrxUsd, priceEndOracle: ", priceEndSfrxUsd, priceEndOracle);
        assertEq({ a: priceEndOracle, b: priceEndSfrxUsd, err: "// THEN: Price end not as expected" });
    }

    function test_previewRateWorks(uint32 value) public doProxyUpgrade {
        uint256 startContract = sfrxusd.previewPricePerShare();
        uint256 startOracle = instance.previewPricePerShare();
        console.log("startOracle: ", startOracle, "startContract: ", startContract);
        assertEq({ a: startOracle, b: startContract, err: "// THEN: Start prices are not the same" });

        uint256 timeToCheck = block.timestamp + value;
        uint256 futureValueContract = sfrxusd.previewPricePerShareFuture(timeToCheck);
        uint256 futureValueOracle = instance.previewPricePerShareFuture(timeToCheck);
        assertEq({ a: futureValueContract, b: futureValueOracle, err: "// THEN: Projected prices are not the same" });
    }

    function test_fuzz_exact_same_rate_no_sync(uint32 timeDelta) public doProxyUpgrade {
        uint256 startContract = sfrxusd.previewPricePerShare();
        uint256 startOracle = instance.previewPricePerShare();
        console.log("startOracle: ", startOracle, "startContract: ", startContract);
        assertEq({ a: startOracle, b: startContract, err: "// THEN: Start prices are not the same" });

        vm.warp(block.timestamp + timeDelta);
        uint256 endContract = sfrxusd.previewPricePerShare();
        uint256 endOracle = instance.previewPricePerShare();
        assertEq({ a: endContract, b: endOracle, err: "// THEN: future prices are not the same" });
    }

    function test_fuzz_small_diff_when_sync(uint32 value) public doProxyUpgrade {
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

    function test_calculateForGiven() public doProxyUpgrade {
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

interface IProxyAdmin {
    function getProxyAdmin() external view returns (address);

    function owner() external view returns (address);

    function upgradeAndCall(address proxy, address impl, bytes memory data) external;
}
