// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { ERC20, ERC4626 } from "solmate/mixins/ERC4626.sol";
import "../Constants.sol" as Constants;
import { StakedFrax, Timelock2Step } from "../contracts/StakedFrax.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { deployStakedFrax, deployDeployAndDepositStakedFrax } from "../script/DeployStakedFrax.s.sol";
import "./Helpers.sol";

contract BaseTest is FraxTest, Constants.Helper {
    using StakedFraxStructHelper for *;

    StakedFrax public stakedFrax;
    address public stakedFraxAddress;

    uint256 public rewardsCycleLength;

    IERC20 public fraxErc20 = IERC20(Constants.Mainnet.FRAX_ERC20);

    function defaultSetup() public {
        vm.createSelectFork(vm.envString("MAINNET_URL"), 18_095_664);

        startHoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        /// BACKGROUND: deploy the StakedFrax contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        stakedFraxAddress = deployDeployAndDepositStakedFrax();
        stakedFrax = StakedFrax(stakedFraxAddress);
        rewardsCycleLength = stakedFrax.REWARDS_CYCLE_LENGTH();
        vm.stopPrank();
    }

    function mintFraxTo(address _to, uint256 _amount) public returns (uint256 _minted) {
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        _minted = _amount;
        IERC20(Constants.Mainnet.FRAX_ERC20).transfer(_to, _minted);
    }
}

function calculateDeltaRewardsCycleData(
    StakedFrax.RewardsCycleData memory _initial,
    StakedFrax.RewardsCycleData memory _final
) pure returns (StakedFrax.RewardsCycleData memory _delta) {
    _delta.cycleEnd = uint32(stdMath.delta(_initial.cycleEnd, _final.cycleEnd));
    _delta.lastSync = uint32(stdMath.delta(_initial.lastSync, _final.lastSync));
    _delta.rewardCycleAmount = uint192(stdMath.delta(_initial.rewardCycleAmount, _final.rewardCycleAmount));
}

struct StakedFraxStorageSnapshot {
    address stakedFraxAddress;
    uint256 maxDistributionPerSecondPerAsset;
    StakedFrax.RewardsCycleData rewardsCycleData;
    uint256 lastRewardsDistribution;
    uint256 storedTotalAssets;
    uint256 totalSupply;
}

struct DeltaStakedFraxStorageSnapshot {
    StakedFraxStorageSnapshot start;
    StakedFraxStorageSnapshot end;
    StakedFraxStorageSnapshot delta;
}

function stakedFraxStorageSnapshot(StakedFrax _stakedFrax) view returns (StakedFraxStorageSnapshot memory _initial) {
    if (address(_stakedFrax) == address(0)) {
        return _initial;
    }
    _initial.stakedFraxAddress = address(_stakedFrax);
    _initial.maxDistributionPerSecondPerAsset = _stakedFrax.maxDistributionPerSecondPerAsset();
    _initial.rewardsCycleData = StakedFraxStructHelper.__rewardsCycleData(_stakedFrax);
    _initial.lastRewardsDistribution = _stakedFrax.lastRewardsDistribution();
    _initial.storedTotalAssets = _stakedFrax.storedTotalAssets();
    _initial.totalSupply = _stakedFrax.totalSupply();
}

function calculateDeltaStakedFraxStorage(
    StakedFraxStorageSnapshot memory _initial,
    StakedFraxStorageSnapshot memory _final
) pure returns (StakedFraxStorageSnapshot memory _delta) {
    _delta.stakedFraxAddress = _initial.stakedFraxAddress == _final.stakedFraxAddress
        ? address(0)
        : _final.stakedFraxAddress;
    _delta.maxDistributionPerSecondPerAsset = stdMath.delta(
        _initial.maxDistributionPerSecondPerAsset,
        _final.maxDistributionPerSecondPerAsset
    );
    _delta.rewardsCycleData = calculateDeltaRewardsCycleData(_initial.rewardsCycleData, _final.rewardsCycleData);
    _delta.lastRewardsDistribution = stdMath.delta(_initial.lastRewardsDistribution, _final.lastRewardsDistribution);
    _delta.storedTotalAssets = stdMath.delta(_initial.storedTotalAssets, _final.storedTotalAssets);
    _delta.totalSupply = stdMath.delta(_initial.totalSupply, _final.totalSupply);
}

function deltaStakedFraxStorageSnapshot(
    StakedFraxStorageSnapshot memory _initial
) view returns (DeltaStakedFraxStorageSnapshot memory _final) {
    _final.start = _initial;
    _final.end = stakedFraxStorageSnapshot(StakedFrax(_initial.stakedFraxAddress));
    _final.delta = calculateDeltaStakedFraxStorage(_final.start, _final.end);
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
    address stakedFraxAddress;
    uint256 balance;
    Erc20UserStorageSnapshot stakedFrax;
    Erc20UserStorageSnapshot asset;
}

struct DeltaUserStorageSnapshot {
    UserStorageSnapshot start;
    UserStorageSnapshot end;
    UserStorageSnapshot delta;
}

function userStorageSnapshot(
    address _user,
    StakedFrax _stakedFrax
) view returns (UserStorageSnapshot memory _snapshot) {
    _snapshot.user = _user;
    _snapshot.stakedFraxAddress = address(_stakedFrax);
    _snapshot.balance = _user.balance;
    _snapshot.stakedFrax.balanceOf = _stakedFrax.balanceOf(_user);
    _snapshot.asset.balanceOf = IERC20(address(_stakedFrax.asset())).balanceOf(_user);
}

function calculateDeltaUserStorageSnapshot(
    UserStorageSnapshot memory _initial,
    UserStorageSnapshot memory _final
) pure returns (UserStorageSnapshot memory _delta) {
    _delta.user = _initial.user == _final.user ? address(0) : _final.user;
    _delta.stakedFraxAddress = _initial.stakedFraxAddress == _final.stakedFraxAddress
        ? address(0)
        : _final.stakedFraxAddress;
    _delta.balance = stdMath.delta(_initial.balance, _final.balance);
    _delta.stakedFrax = calculateDeltaErc20UserStorageSnapshot(_initial.stakedFrax, _final.stakedFrax);
    _delta.asset = calculateDeltaErc20UserStorageSnapshot(_initial.asset, _final.asset);
}

function deltaUserStorageSnapshot(
    UserStorageSnapshot memory _initial
) view returns (DeltaUserStorageSnapshot memory _snapshot) {
    _snapshot.start = _initial;
    _snapshot.end = userStorageSnapshot(_initial.user, StakedFrax(_initial.stakedFraxAddress));
    _snapshot.delta = calculateDeltaUserStorageSnapshot(_snapshot.start, _snapshot.end);
}
