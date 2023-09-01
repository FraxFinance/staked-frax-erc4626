// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { ERC20, ERC4626 } from "solmate/mixins/ERC4626.sol";
import "../Constants.sol" as Constants;
import { SavingsFrax, Timelock2Step } from "../contracts/SavingsFrax.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { deploySavingsFrax, deployDeployAndDepositSavingsFrax } from "../script/DeploySavingsFrax.s.sol";
import "./Helpers.sol";

contract BaseTest is FraxTest, Constants.Helper {
    using SavingsFraxStructHelper for *;

    SavingsFrax public savingsFrax;
    address public savingsFraxAddress;

    uint256 public rewardsCycleLength;

    IERC20 public fraxErc20 = IERC20(Constants.Mainnet.FRAX_ERC20);

    function defaultSetup() public {
        vm.createSelectFork(vm.envString("MAINNET_URL"), 18_095_664);

        startHoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        /// BACKGROUND: deploy the SavingsFrax contract
        /// BACKGROUND: 10% APY
        /// BACKGROUND: frax as the underlying asset
        /// BACKGROUND: TIMELOCK_ADDRESS set as the timelock address
        savingsFraxAddress = deployDeployAndDepositSavingsFrax();
        savingsFrax = SavingsFrax(savingsFraxAddress);
        rewardsCycleLength = savingsFrax.REWARDS_CYCLE_LENGTH();
        vm.stopPrank();

        // // BACKGROUND: current timestamp is the ending of the last cycle
        // vm.warp(savingsFrax.__rewardsCycleData().cycleEnd);

        /// GIVEN: A totalSupply of Shares is 1000
        assertEq(savingsFrax.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// GIVEN: storedTotalAssets is 1
        assertEq(savingsFrax.storedTotalAssets(), 1000 ether, "setup: storedTotalAssets should be 1000");
    }

    function mintFraxTo(address _to, uint256 _amount) public returns (uint256 _minted) {
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        _minted = _amount;
        IERC20(Constants.Mainnet.FRAX_ERC20).transfer(_to, _minted);
    }
}

function deltaRewardsCycleData(
    SavingsFrax.RewardsCycleData memory _initial,
    SavingsFrax.RewardsCycleData memory _final
) pure returns (SavingsFrax.RewardsCycleData memory _delta) {
    _delta.cycleEnd = uint32(stdMath.delta(_initial.cycleEnd, _final.cycleEnd));
    _delta.lastSync = uint32(stdMath.delta(_initial.lastSync, _final.lastSync));
    _delta.rewardCycleAmount = uint192(stdMath.delta(_initial.rewardCycleAmount, _final.rewardCycleAmount));
}

struct SavingsFraxStorageSnapshot {
    address savingsFraxAddress;
    uint256 maxDistributionPerSecondPerAsset;
    SavingsFrax.RewardsCycleData rewardsCycleData;
    uint256 lastRewardsDistribution;
    uint256 storedTotalAssets;
    uint256 totalSupply;
}

struct DeltaSavingsFraxStorageSnapshot {
    SavingsFraxStorageSnapshot start;
    SavingsFraxStorageSnapshot end;
    SavingsFraxStorageSnapshot delta;
}

function savingsFraxStorageSnapshot(
    SavingsFrax _savingsFrax
) view returns (SavingsFraxStorageSnapshot memory _initial) {
    if (address(_savingsFrax) == address(0)) {
        return _initial;
    }
    _initial.savingsFraxAddress = address(_savingsFrax);
    _initial.maxDistributionPerSecondPerAsset = _savingsFrax.maxDistributionPerSecondPerAsset();
    _initial.rewardsCycleData = SavingsFraxStructHelper.__rewardsCycleData(_savingsFrax);
    _initial.lastRewardsDistribution = _savingsFrax.lastRewardsDistribution();
    _initial.storedTotalAssets = _savingsFrax.storedTotalAssets();
    _initial.totalSupply = _savingsFrax.totalSupply();
}

function calculateDeltaSavingsFraxStorage(
    SavingsFraxStorageSnapshot memory _initial,
    SavingsFraxStorageSnapshot memory _final
) pure returns (SavingsFraxStorageSnapshot memory _delta) {
    _delta.savingsFraxAddress = _initial.savingsFraxAddress == _final.savingsFraxAddress
        ? address(0)
        : _final.savingsFraxAddress;
    _delta.maxDistributionPerSecondPerAsset = stdMath.delta(
        _initial.maxDistributionPerSecondPerAsset,
        _final.maxDistributionPerSecondPerAsset
    );
    _delta.rewardsCycleData = deltaRewardsCycleData(_initial.rewardsCycleData, _final.rewardsCycleData);
    _delta.lastRewardsDistribution = stdMath.delta(_initial.lastRewardsDistribution, _final.lastRewardsDistribution);
    _delta.storedTotalAssets = stdMath.delta(_initial.storedTotalAssets, _final.storedTotalAssets);
    _delta.totalSupply = stdMath.delta(_initial.totalSupply, _final.totalSupply);
}

function deltaSavingsFraxStorageSnapshot(
    SavingsFraxStorageSnapshot memory _initial
) view returns (DeltaSavingsFraxStorageSnapshot memory _final) {
    _final.start = _initial;
    _final.end = savingsFraxStorageSnapshot(SavingsFrax(_initial.savingsFraxAddress));
    _final.delta = calculateDeltaSavingsFraxStorage(_final.start, _final.end);
}
