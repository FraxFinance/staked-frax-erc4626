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

contract GenSfrxUSD2UpgradeBatch is BaseScript {
    ProxyAdmin pxyAdmin;

    function run() public broadcaster {
        // Start broadcasting
        console.log("Executing as", msg.sender);

        // Find the proxy admin
        // Should be 0xeA0a6EC8114a0Af6Cf74Ca0036Ab31d892Df13cB
        bytes32 adminSlot = vm.load(Constants.Mainnet.SFRXUSD_PXY, ERC1967Utils.ADMIN_SLOT);
        pxyAdmin = ProxyAdmin(address(uint160(uint256(adminSlot))));
        console.log("Proxy Admin: ", address(pxyAdmin));
    }
}
