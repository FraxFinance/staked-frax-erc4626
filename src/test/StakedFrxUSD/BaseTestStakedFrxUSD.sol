// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { ERC20, ERC4626 } from "solmate/mixins/ERC4626.sol";
import "../../Constants.sol" as Constants;
import { StakedFrxUSD, Timelock2Step } from "../../contracts/StakedFrxUSD.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { deployStakedFrxUSD, deployDeployAndDepositStakedFrxUSD } from "../../script/DeployStakedFrxUSD.s.sol";
import "../Helpers.sol";

contract BaseTestStakedFrxUSD is FraxTest, Constants.Helper {
    using StakedFrxUSDStructHelper for *;

    StakedFrxUSD public stakedFrxUSD;

    address public stakedFrxUSDAddress;

    uint256 public rewardsCycleLength;

    IERC20 public fraxErc20 = IERC20(0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29);

    function defaultSetup() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_543_360);
        deal(address(fraxErc20), Constants.Mainnet.FRAX_ERC20_OWNER, 1_000_000e18);

        startHoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        /// BACKGROUND: deploy the StakedFrxUSD contract
        /// BACKGROUND: 10% APY cap
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        stakedFrxUSDAddress = deployDeployAndDepositStakedFrxUSD();
        stakedFrxUSD = StakedFrxUSD(stakedFrxUSDAddress);
        rewardsCycleLength = stakedFrxUSD.REWARDS_CYCLE_LENGTH();
        vm.stopPrank();
    }

    function mintFraxTo(address _to, uint256 _amount) public returns (uint256 _minted) {
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        _minted = _amount;
        fraxErc20.transfer(_to, _minted);
    }
}

function calculateDeltaRewardsCycleData(
    StakedFrxUSD.RewardsCycleData memory _initial,
    StakedFrxUSD.RewardsCycleData memory _final
) pure returns (StakedFrxUSD.RewardsCycleData memory _delta) {
    _delta.cycleEnd = uint32(stdMath.delta(_initial.cycleEnd, _final.cycleEnd));
    _delta.lastSync = uint32(stdMath.delta(_initial.lastSync, _final.lastSync));
    _delta.rewardCycleAmount = uint192(stdMath.delta(_initial.rewardCycleAmount, _final.rewardCycleAmount));
}

struct StakedFrxUSDStorageSnapshot {
    address stakedFrxUSDAddress;
    uint256 maxDistributionPerSecondPerAsset;
    StakedFrxUSD.RewardsCycleData rewardsCycleData;
    uint256 lastRewardsDistribution;
    uint256 storedTotalAssets;
    uint256 totalSupply;
}

struct DeltaStakedFrxUSDStorageSnapshot {
    StakedFrxUSDStorageSnapshot start;
    StakedFrxUSDStorageSnapshot end;
    StakedFrxUSDStorageSnapshot delta;
}

function stakedFrxUSDStorageSnapshot(
    StakedFrxUSD _stakedFrxUSD
) view returns (StakedFrxUSDStorageSnapshot memory _initial) {
    if (address(_stakedFrxUSD) == address(0)) {
        return _initial;
    }
    _initial.stakedFrxUSDAddress = address(_stakedFrxUSD);
    _initial.maxDistributionPerSecondPerAsset = _stakedFrxUSD.maxDistributionPerSecondPerAsset();
    _initial.rewardsCycleData = StakedFrxUSDStructHelper.__rewardsCycleData(_stakedFrxUSD);
    _initial.lastRewardsDistribution = _stakedFrxUSD.lastRewardsDistribution();
    _initial.storedTotalAssets = _stakedFrxUSD.storedTotalAssets();
    _initial.totalSupply = _stakedFrxUSD.totalSupply();
}

function calculateDeltaStakedFrxUSDStorage(
    StakedFrxUSDStorageSnapshot memory _initial,
    StakedFrxUSDStorageSnapshot memory _final
) pure returns (StakedFrxUSDStorageSnapshot memory _delta) {
    _delta.stakedFrxUSDAddress = _initial.stakedFrxUSDAddress == _final.stakedFrxUSDAddress
        ? address(0)
        : _final.stakedFrxUSDAddress;
    _delta.maxDistributionPerSecondPerAsset = stdMath.delta(
        _initial.maxDistributionPerSecondPerAsset,
        _final.maxDistributionPerSecondPerAsset
    );
    _delta.rewardsCycleData = calculateDeltaRewardsCycleData(_initial.rewardsCycleData, _final.rewardsCycleData);
    _delta.lastRewardsDistribution = stdMath.delta(_initial.lastRewardsDistribution, _final.lastRewardsDistribution);
    _delta.storedTotalAssets = stdMath.delta(_initial.storedTotalAssets, _final.storedTotalAssets);
    _delta.totalSupply = stdMath.delta(_initial.totalSupply, _final.totalSupply);
}

function deltaStakedFrxUSDStorageSnapshot(
    StakedFrxUSDStorageSnapshot memory _initial
) view returns (DeltaStakedFrxUSDStorageSnapshot memory _final) {
    _final.start = _initial;
    _final.end = stakedFrxUSDStorageSnapshot(StakedFrxUSD(_initial.stakedFrxUSDAddress));
    _final.delta = calculateDeltaStakedFrxUSDStorage(_final.start, _final.end);
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
    address stakedFrxUSDAddress;
    uint256 balance;
    Erc20UserStorageSnapshot stakedFrxUSD;
    Erc20UserStorageSnapshot asset;
}

struct DeltaUserStorageSnapshot {
    UserStorageSnapshot start;
    UserStorageSnapshot end;
    UserStorageSnapshot delta;
}

function userStorageSnapshot(
    address _user,
    StakedFrxUSD _stakedFrxUSD
) view returns (UserStorageSnapshot memory _snapshot) {
    _snapshot.user = _user;
    _snapshot.stakedFrxUSDAddress = address(_stakedFrxUSD);
    _snapshot.balance = _user.balance;
    _snapshot.stakedFrxUSD.balanceOf = _stakedFrxUSD.balanceOf(_user);
    _snapshot.asset.balanceOf = IERC20(address(_stakedFrxUSD.asset())).balanceOf(_user);
}

function calculateDeltaUserStorageSnapshot(
    UserStorageSnapshot memory _initial,
    UserStorageSnapshot memory _final
) pure returns (UserStorageSnapshot memory _delta) {
    _delta.user = _initial.user == _final.user ? address(0) : _final.user;
    _delta.stakedFrxUSDAddress = _initial.stakedFrxUSDAddress == _final.stakedFrxUSDAddress
        ? address(0)
        : _final.stakedFrxUSDAddress;
    _delta.balance = stdMath.delta(_initial.balance, _final.balance);
    _delta.stakedFrxUSD = calculateDeltaErc20UserStorageSnapshot(_initial.stakedFrxUSD, _final.stakedFrxUSD);
    _delta.asset = calculateDeltaErc20UserStorageSnapshot(_initial.asset, _final.asset);
}

function deltaUserStorageSnapshot(
    UserStorageSnapshot memory _initial
) view returns (DeltaUserStorageSnapshot memory _snapshot) {
    _snapshot.start = _initial;
    _snapshot.end = userStorageSnapshot(_initial.user, StakedFrxUSD(_initial.stakedFrxUSDAddress));
    _snapshot.delta = calculateDeltaUserStorageSnapshot(_snapshot.start, _snapshot.end);
}
