// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "./BaseTestStakedFrxUSD.sol";
import "../../contracts/StakedFrax.sol";
import { DeployAndDepositStakedFrxUSD } from "../../script/DeployStakedFrxUSD.s.sol";
import { FrxUSD } from "../../contracts/FrxUSD.sol";

contract ForkTestDeploy is BaseTestStakedFrxUSD {
    using StakedFrxUSDStructHelper for *;

    address constant SFRAX_ERC4626 = 0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32;
    address constant FRXUSD = 0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29;

    DeployAndDepositStakedFrxUSD deployAndDepositStakedFrxUSD =
        DeployAndDepositStakedFrxUSD(0x2F9ddCe443db5Aa262dA566f250ae14e49f6d725);

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_564_929);
        vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);
        FrxUSD(FRXUSD).addMinter(Constants.Mainnet.FRAX_ERC20_OWNER);
        FrxUSD(FRXUSD).minter_mint(Constants.Mainnet.FRAX_ERC20_OWNER, 1_000_000e18);
        FrxUSD(FRXUSD).transfer(address(deployAndDepositStakedFrxUSD), 2000e18);
        vm.stopPrank();
        stakedFrxUSDAddress = deployAndDepositStakedFrxUSD.deployStakedFrxUSDAndDeposit();
        stakedFrxUSD = StakedFrxUSD(stakedFrxUSDAddress);
        rewardsCycleLength = stakedFrxUSD.REWARDS_CYCLE_LENGTH();
    }

    function test_Deploy() public {
        StakedFrax stakedFrax = StakedFrax(0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32);

        /// SCENARIO: The deployment is as expected after the deploy script is used

        /// WHEN: StakedFrxUSD contract is deployed

        /// THEN: A totalSupply of Shares is 1000
        assertEq(stakedFrxUSD.totalSupply(), 1000 ether, "setup:totalSupply should be 1000");

        /// THEN: storedTotalAssets is 1000
        assertEq(
            stakedFrxUSD.storedTotalAssets(),
            ((1000 ether) * stakedFrax.pricePerShare()) / 1e18,
            "setup: storedTotalAssets should be 1000"
        );

        /// THEN: cycleEnd next full cycle multiplied from unix epoch
        assertEq(
            stakedFrxUSD.__rewardsCycleData().cycleEnd,
            ((block.timestamp + rewardsCycleLength) / rewardsCycleLength) * rewardsCycleLength,
            "setup: cycleEnd should be next full cycle multiplied from unix epoch"
        );

        (uint40 _cycleEnd, uint40 _lastSync, uint216 _rewardCycleAmount) = stakedFrax.rewardsCycleData();

        /// THEN: lastSync is same as sFRAX
        assertEq(
            stakedFrxUSD.__rewardsCycleData().lastSync,
            _lastSync,
            "setup: lastSync should be equal to lastSync of sFRAX"
        );

        /// THEN: _cycleEnd is same as sFRAX
        assertEq(
            stakedFrxUSD.__rewardsCycleData().cycleEnd,
            _cycleEnd,
            "setup: cycleEnd should be equal to cycleEnd of sFRAX"
        );

        /*/// THEN: rewardsForDistribution is same as sFRAX
        assertEq(stakedFrxUSD.__rewardsCycleData().rewardCycleAmount, _rewardCycleAmount, "setup: rewardsForDistribution should be equal to rewardsForDistribution of sFRAX");*/

        /// THEN: lastDistributionTime is same as sFRAX
        assertEq(
            stakedFrxUSD.lastRewardsDistribution(),
            stakedFrax.lastRewardsDistribution(),
            "setup: lastDistributionTime should be equal to lastDistributionTime of sFRAX"
        );

        /// THEN: rewardsCycleLength is 7 days
        assertEq(stakedFrxUSD.REWARDS_CYCLE_LENGTH(), 7 days, "setup: rewardsCycleLength should be 7 days");

        /// THEN: maxDistributionPerSecondPerAsset is ame as sFRAX
        assertEq(
            stakedFrxUSD.maxDistributionPerSecondPerAsset(),
            stakedFrax.maxDistributionPerSecondPerAsset(),
            "setup: maxDistributionPerSecondPerAsset should be equal to maxDistributionPerSecondPerAsset of sFRAX"
        );

        /// THEN: pricePerShare is same as sFRAX
        assertEq(
            stakedFrxUSD.pricePerShare(),
            stakedFrax.pricePerShare(),
            "setup: pricePerShare should be equal to pricePerShare of sFRAX"
        );
    }

    function test_InSync() public {
        StakedFrax stakedFrax = StakedFrax(0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32);
        assertEq(
            stakedFrxUSD.pricePerShare(),
            stakedFrax.pricePerShare(),
            "pricePerShare should be equal to pricePerShare of sFRAX"
        );

        for (uint256 i = 0; i < 24 * 7; ++i) {
            // wait 8 hours
            vm.warp(block.timestamp + 8 * 60 * 60);

            // sFRAX and sfrxUSD should be in sync
            assertApproxEqAbs(
                stakedFrxUSD.pricePerShare(),
                stakedFrax.pricePerShare(),
                1,
                "pricePerShare should be equal to pricePerShare of sFRAX"
            );
            vm.startPrank(Constants.Mainnet.FRAX_ERC20_OWNER);

            // Deposit
            stakedFrax.deposit(10e18, Constants.Mainnet.FRAX_ERC20_OWNER);
            FrxUSD(FRXUSD).approve(address(stakedFrxUSD), 10e18);
            stakedFrxUSD.deposit(10e18, Constants.Mainnet.FRAX_ERC20_OWNER);

            // Add rewards
            FrxUSD(FRXUSD).transfer(address(stakedFrxUSD), 1000e18);
            FrxUSD(Constants.Mainnet.FRAX_ERC20).transfer(address(stakedFrax), 10_000e18);
            vm.stopPrank();

            // Do the sync in the same block
            stakedFrax.syncRewardsAndDistribution();
            stakedFrxUSD.syncRewardsAndDistribution();
        }
    }
}
