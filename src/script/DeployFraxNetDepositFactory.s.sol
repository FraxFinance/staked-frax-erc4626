// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { FraxNetDepositFactory } from "../contracts/FraxNetDepositFactory.sol";
import { IFrxUSDCustodian } from "../contracts/interfaces/IFrxUSDCustodian.sol";
import { IRemoteHop } from "../contracts/interfaces/IRemoteHop.sol";
import "../Constants.sol" as Constants;

// Deploys the FrxUSDMigrator contract
contract DeployFraxNetDepositFactory is BaseScript {
    function run() public broadcaster {
        IFrxUSDCustodian frxUSDCustodian = IFrxUSDCustodian(0x4F95C5bA0C7c69FB2f9340E190cCeE890B3bd87c);
        IRemoteHop remoteHop = IRemoteHop(0x4DDDc830c7C9a0CfcB941416B92D75F12423bc37);
        FraxNetDepositFactory _factory = new FraxNetDepositFactory(frxUSDCustodian, remoteHop);
        console.log("FraxNetDepositFactory deployed at:", address(_factory));
    }
}
