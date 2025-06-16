// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { ERC20, ERC4626 } from "solmate/mixins/ERC4626.sol";
import "../../Constants.sol" as Constants;
import { StakedFrxUSD } from "../../contracts/StakedFrxUSD.sol";
import { StakedFrxUSD2, Timelock2Step } from "../../contracts/StakedFrxUSD2.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { mul, div, ln } from "@prb/math/src/ud60x18/Math.sol";
import { convert } from "@prb/math/src/ud60x18/Conversions.sol";
import { UD60x18 } from "@prb/math/src/ud60x18/ValueType.sol";
import { DeployStakedFrxUSD2 } from "../../script/DeployStakedFrxUSD2.s.sol";
import "../Helpers.sol";

contract BaseTestStakedFrxUSD2 is FraxTest, Constants.Helper {
    // ProxyAdmin
    ProxyAdmin public pxyAdmin;

    // frxUSD
    IERC20 public frxUSDErc20 = IERC20(0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29);

    // sfrxUSD
    StakedFrxUSD2 public sfrxUSD2 = StakedFrxUSD2(0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6);
    StakedFrxUSD2 public stakedFrxUSD2_impl;
    address public sfrxUSD1_Old_Impl = 0x4486c140aFABe2B4ee98CB2a67A0E711eb063baF;
    address public stakedFrxUSD2Address = 0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6;
    ITransparentUpgradeableProxy public stakedFrxUSD2_pxy =
        ITransparentUpgradeableProxy(0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6);

    // For sfrxUSD2 initialization
    uint256[2] ppsInfo;

    // Snapshots and deltas
    // ---------------------------
    // Storage
    StakedFrxUSD2StorageSnapshot public preUpgradeStorageSnapshot;
    StakedFrxUSD2StorageSnapshot public postUpgradeStorageSnapshot;
    StakedFrxUSD2StorageSnapshot public postAfterUpgradeSyncStorageSnapshot;
    StakedFrxUSD2StorageSnapshot public calcedDeltaPostUpgradeStorageSnapshot;
    StakedFrxUSD2StorageSnapshot public calcedDeltaAfterUpgradeSyncStorageSnapshot;

    // Alice (test user)
    UserStorageSnapshot public preUpgradeAliceSnapshot;
    UserStorageSnapshot public postUpgradeAliceSnapshot;
    UserStorageSnapshot public postAfterUpgradeSyncAliceSnapshot;
    UserStorageSnapshot public calcedDeltaPostUpgradeAliceSnapshot;
    UserStorageSnapshot public calcedDeltaAfterUpgradeSyncAliceSnapshot;

    // Test users
    uint256 public alicePrivateKey;
    uint256 public bobPrivateKey;
    address payable public alice;
    address payable public bob;
    uint256 public aliceStartSfrxUSD;

    // Constants
    uint256 public constant ONE_MILLION_E18 = 1_000_000e18;
    uint256 public constant ONE_BILLION_E18 = 1_000_000_000e18;
    uint256 public constant ONE_TRILLION_E18 = 1_000_000_000_000e18;
    uint256 public constant ONE_MONTH = 2_629_746;
    uint256 public constant ONE_YEAR = 31_536_000;

    function defaultSetup() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 22_326_431);
        deal(address(frxUSDErc20), Constants.Mainnet.FRAX_ERC20_OWNER, 1_000_000e18);

        // Label contracts
        vm.label(address(frxUSDErc20), "frxUSD_Pxy");
        vm.label(sfrxUSD1_Old_Impl, "sfrxUSD1_Impl_Old");
        vm.label(stakedFrxUSD2Address, "sfrxUSD2_Pxy");

        // Set up Alice
        alicePrivateKey = 0xA11CE;
        alice = payable(vm.addr(alicePrivateKey));
        vm.label(alice, "Alice");

        // Set up Bob
        bobPrivateKey = 0xB0B;
        bob = payable(vm.addr(bobPrivateKey));
        vm.label(bob, "Bob");

        // Give Alice some frxUSD
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        frxUSDErc20.transfer(alice, 500_000e18);

        // Give Bob some frxUSD
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        frxUSDErc20.transfer(bob, 250_000e18);

        // Alice mints 1000 frxUSD worth of sfrxUSD
        startHoax(alice);
        frxUSDErc20.approve(stakedFrxUSD2Address, 1000e18);
        console.log("Alice's frxUSD before deposit: ", frxUSDErc20.balanceOf(alice));
        sfrxUSD2.deposit(1000e18, alice);
        console.log("Alice's frxUSD after deposit: ", frxUSDErc20.balanceOf(alice));
        require(frxUSDErc20.balanceOf(alice) == 500_000e18 - 1000e18, "Alice should have 1000 less frxUSD now");
        aliceStartSfrxUSD = sfrxUSD2.balanceOf(alice);
        console.log("Alice's starting sfrxUSD: ", aliceStartSfrxUSD);
        vm.stopPrank();

        // Take snapshots before the upgrade
        preUpgradeStorageSnapshot = stakedFrxUSD2StorageSnapshotBeforeUpgrade(sfrxUSD2);
        preUpgradeAliceSnapshot = userStorageSnapshot(alice, sfrxUSD2);

        // Deploy the sfrxUSD2 impl
        stakedFrxUSD2_impl = (new DeployStakedFrxUSD2()).runTest();
        vm.label(address(stakedFrxUSD2_impl), "stakedFrxUSD2_Impl_New");

        // Find the proxy admin
        // Should be 0xeA0a6EC8114a0Af6Cf74Ca0036Ab31d892Df13cB
        bytes32 adminSlot = vm.load(address(stakedFrxUSD2_pxy), ERC1967Utils.ADMIN_SLOT);
        pxyAdmin = ProxyAdmin(address(uint160(uint256(adminSlot))));
        console.log("Proxy Admin: ", address(pxyAdmin));

        // Fetch current pricePerShare and set other vars
        // [0] Initial PricePerShare [1] PricePerShare increase per sec, in assets [2] Maximum PricePerShare
        // -----------------------

        // Initial pricePerShare
        ppsInfo[0] = sfrxUSD2.pricePerShare();

        // To calculate the rate
        // Continuously compounding interest. Done here instead of in _previewTotalAssets
        // Might be an easier way to do this...
        // https://people.math.wisc.edu/~gemeyer/math141/L11.html
        // p(t) = p₀ * e^((dr)*t)
        // 1.05e18 = 1e18 * e^(dr * 31536000)
        // ln(1.05e18) = ln(1e18) + (dr * 31536000)
        // dr = (ln(1.05e18)*1e18 - ln(1e18)*1e18) / 31536000 /// 1e18 scaling applied
        ppsInfo[1] = stakedFrxUSD2_impl.calcPPSIPSForGivenAPY(1.05e18);

        // Print info
        console.log("======== Initial ========");
        console.log("PPS: ", ppsInfo[0]);
        console.log("Calculated PPSPS: ", ppsInfo[1]);
        console.log("totalAssets: ", sfrxUSD2.totalAssets());
        console.log("storedTotalAssets: ", sfrxUSD2.storedTotalAssets());
        console.log("totalSupply: ", sfrxUSD2.totalSupply());

        // Upgrade the proxy
        startHoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        bytes memory data = abi.encodeCall(
            stakedFrxUSD2_impl.initialize,
            ("Staked Frax USD", "sfrxUSD", Constants.Mainnet.FRAX_ERC20_OWNER, ppsInfo)
        );
        pxyAdmin.upgradeAndCall(stakedFrxUSD2_pxy, address(stakedFrxUSD2_impl), data);
        vm.stopPrank();

        // Take snapshots and deltas after the upgrade
        postUpgradeStorageSnapshot = stakedFrxUSD2StorageSnapshot(sfrxUSD2);
        calcedDeltaPostUpgradeStorageSnapshot = calculateDeltaStakedFrxUSD2Storage(
            preUpgradeStorageSnapshot,
            postUpgradeStorageSnapshot
        );
        postUpgradeAliceSnapshot = userStorageSnapshot(alice, sfrxUSD2);
        calcedDeltaPostUpgradeAliceSnapshot = calculateDeltaUserStorageSnapshot(
            preUpgradeAliceSnapshot,
            postUpgradeAliceSnapshot
        );

        // Print info
        console.log("======== After upgrade ========");
        console.log("PPS: ", sfrxUSD2.pricePerShare());
        console.log("PPSPS: ", sfrxUSD2.pricePerShareIncPerSecond());
        console.log("totalAssets: ", sfrxUSD2.totalAssets());
        console.log("storedTotalAssets: ", sfrxUSD2.storedTotalAssets());
        console.log("totalSupply: ", sfrxUSD2.totalSupply());
        {
            (uint256 _pricePerShare, uint256 _totalAssets) = sfrxUSD2.previewPPSAndTotalAssets();
            console.log("preview _pricePerShare: ", _pricePerShare);
            console.log("preview _totalAssets: ", _totalAssets);
        }
    }

    function mintFraxTo(address _to, uint256 _amount) public returns (uint256 _minted) {
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        _minted = _amount;
        frxUSDErc20.transfer(_to, _minted);
    }

    function _warpToAndRollOne(uint256 _newTs) public {
        vm.warp(_newTs);
        vm.roll(block.number + 1);
    }
}

struct StakedFrxUSD2StorageSnapshot {
    address stakedFrxUSD2Address;
    uint256 storedTotalAssets;
    uint256 pricePerShareStored;
    uint256 pricePerShareIncPerSecond;
    uint256 lastSync;
    uint256 totalSupply;
}

struct DeltaStakedFrxUSD2StorageSnapshot {
    StakedFrxUSD2StorageSnapshot start;
    StakedFrxUSD2StorageSnapshot end;
    StakedFrxUSD2StorageSnapshot delta;
}

function stakedFrxUSD2StorageSnapshotBeforeUpgrade(
    StakedFrxUSD2 _stakedFrxUSD2
) view returns (StakedFrxUSD2StorageSnapshot memory _initial) {
    _initial.stakedFrxUSD2Address = address(_stakedFrxUSD2);
    _initial.storedTotalAssets = _stakedFrxUSD2.storedTotalAssets();
    _initial.pricePerShareStored = 0;
    _initial.pricePerShareIncPerSecond = 0;
    _initial.lastSync = 0;
    _initial.totalSupply = _stakedFrxUSD2.totalSupply();
}

function stakedFrxUSD2StorageSnapshot(
    StakedFrxUSD2 _stakedFrxUSD2
) view returns (StakedFrxUSD2StorageSnapshot memory _initial) {
    if (address(_stakedFrxUSD2) == address(0)) {
        return _initial;
    }
    _initial.stakedFrxUSD2Address = address(_stakedFrxUSD2);
    _initial.storedTotalAssets = _stakedFrxUSD2.storedTotalAssets();
    _initial.pricePerShareStored = _stakedFrxUSD2.pricePerShareStored();
    _initial.pricePerShareIncPerSecond = _stakedFrxUSD2.pricePerShareIncPerSecond();
    _initial.lastSync = _stakedFrxUSD2.lastSync();
    _initial.totalSupply = _stakedFrxUSD2.totalSupply();
}

function calculateDeltaStakedFrxUSD2Storage(
    StakedFrxUSD2StorageSnapshot memory _initial,
    StakedFrxUSD2StorageSnapshot memory _final
) pure returns (StakedFrxUSD2StorageSnapshot memory _delta) {
    _delta.stakedFrxUSD2Address = _initial.stakedFrxUSD2Address == _final.stakedFrxUSD2Address
        ? address(0)
        : _final.stakedFrxUSD2Address;
    _delta.storedTotalAssets = stdMath.delta(_initial.storedTotalAssets, _final.storedTotalAssets);
    _delta.pricePerShareStored = stdMath.delta(_initial.pricePerShareStored, _final.pricePerShareStored);
    _delta.pricePerShareIncPerSecond = stdMath.delta(
        _initial.pricePerShareIncPerSecond,
        _final.pricePerShareIncPerSecond
    );
    _delta.lastSync = stdMath.delta(_initial.lastSync, _final.lastSync);
    _delta.totalSupply = stdMath.delta(_initial.totalSupply, _final.totalSupply);
}

function deltaStakedFrxUSD2StorageSnapshot(
    StakedFrxUSD2StorageSnapshot memory _initial
) view returns (DeltaStakedFrxUSD2StorageSnapshot memory _final) {
    _final.start = _initial;
    _final.end = stakedFrxUSD2StorageSnapshot(StakedFrxUSD2(_initial.stakedFrxUSD2Address));
    _final.delta = calculateDeltaStakedFrxUSD2Storage(_final.start, _final.end);
}

//==============================================================================
// User Snapshot Functions
//==============================================================================

struct Erc20UserStorageSnapshot {
    uint256 balanceOf;
}

function calculateDeltaErc20UserStorageSnapshot(
    Erc20UserStorageSnapshot memory _initial,
    Erc20UserStorageSnapshot memory _final
) pure returns (Erc20UserStorageSnapshot memory _delta) {
    _delta.balanceOf = stdMath.delta(_initial.balanceOf, _final.balanceOf);
}

struct UserStorageSnapshot {
    address user;
    address stakedFrxUSD2Address;
    uint256 balance;
    Erc20UserStorageSnapshot stakedFrxUSD2;
    Erc20UserStorageSnapshot asset;
}

struct DeltaUserStorageSnapshot {
    UserStorageSnapshot start;
    UserStorageSnapshot end;
    UserStorageSnapshot delta;
}

function userStorageSnapshot(
    address _user,
    StakedFrxUSD2 _stakedFrxUSD2
) view returns (UserStorageSnapshot memory _snapshot) {
    _snapshot.user = _user;
    _snapshot.stakedFrxUSD2Address = address(_stakedFrxUSD2);
    _snapshot.balance = _user.balance;
    _snapshot.stakedFrxUSD2.balanceOf = _stakedFrxUSD2.balanceOf(_user);
    _snapshot.asset.balanceOf = IERC20(address(_stakedFrxUSD2.asset())).balanceOf(_user);
}

function calculateDeltaUserStorageSnapshot(
    UserStorageSnapshot memory _initial,
    UserStorageSnapshot memory _final
) pure returns (UserStorageSnapshot memory _delta) {
    _delta.user = _initial.user == _final.user ? address(0) : _final.user;
    _delta.stakedFrxUSD2Address = _initial.stakedFrxUSD2Address == _final.stakedFrxUSD2Address
        ? address(0)
        : _final.stakedFrxUSD2Address;
    _delta.balance = stdMath.delta(_initial.balance, _final.balance);
    _delta.stakedFrxUSD2 = calculateDeltaErc20UserStorageSnapshot(_initial.stakedFrxUSD2, _final.stakedFrxUSD2);
    _delta.asset = calculateDeltaErc20UserStorageSnapshot(_initial.asset, _final.asset);
}

function deltaUserStorageSnapshot(
    UserStorageSnapshot memory _initial
) view returns (DeltaUserStorageSnapshot memory _snapshot) {
    _snapshot.start = _initial;
    _snapshot.end = userStorageSnapshot(_initial.user, StakedFrxUSD2(_initial.stakedFrxUSD2Address));
    _snapshot.delta = calculateDeltaUserStorageSnapshot(_snapshot.start, _snapshot.end);
}
