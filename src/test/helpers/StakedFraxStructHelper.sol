// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../../contracts/StakedFrax.sol";

library StakedFraxStructHelper {
    function __rewardsCycleData(
        StakedFrax _stakedFrax
    ) internal view returns (StakedFrax.RewardsCycleData memory _return) {
        (_return.cycleEnd, _return.lastSync, _return.rewardCycleAmount) = _stakedFrax.rewardsCycleData();
    }
}
