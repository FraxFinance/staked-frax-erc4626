// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { StakedFrxUSD2 } from "src/contracts/StakedFrxUSD2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../Constants.sol" as Constants;

contract DeploySfrxUSDImpl is BaseScript {
    StakedFrxUSD2 sfrxUSD2Impl;

    function run() public broadcaster {
        // Start broadcasting
        console.log("Executing as", msg.sender);

        console.log("Deploy the implementation for StakedFrxUSD2");
        // =======================================================
        sfrxUSD2Impl = new StakedFrxUSD2({
            _underlying: IERC20(Constants.Mainnet.FRXUSD),
            _name: "Staked Frax USD",
            _symbol: "sfrxUSD",
            _timelockAddress: Constants.Mainnet.FRAX_ERC20_OWNER
        });

        console.log("===================== StakedFrxUSD2 IMPL ADDRESS =====================");
        console.log("address internal constant SFRXUSD2_IMPL_ADDRESS = %s;", address(sfrxUSD2Impl));
    }
}
