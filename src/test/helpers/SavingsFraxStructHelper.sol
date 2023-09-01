// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "../../contracts/SavingsFrax.sol";

library SavingsFraxStructHelper {
    function __rewardsCycleData(
        SavingsFrax _savingsFrax
    ) internal view returns (SavingsFrax.RewardsCycleData memory _return) {
        (_return.cycleEnd, _return.lastSync, _return.rewardCycleAmount) = _savingsFrax.rewardsCycleData();
    }
}
