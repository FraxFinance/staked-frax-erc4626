// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { StakedFrxUSD } from "../contracts/StakedFrxUSD.sol";
import { StakedFrxUSD2 } from "../contracts/StakedFrxUSD2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../Constants.sol" as Constants;

address constant FRXUSD = 0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29;
address constant SFRXUSD_PXY = 0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6;

function deployStakedFrxUSD2() returns (StakedFrxUSD2 _stakedFrxUSD2) {
    // uint256 TEN_PERCENT = 3_022_266_030; // per second rate compounded week each block (1.10^(365 * 86400 / 12) - 1) / 12 * 1e18
    // uint256 FIVE_PERCENT = ((1.05 ** (365 * 86400 / 12) - 1) / 12) * 1e18;

    _stakedFrxUSD2 = new StakedFrxUSD2({
        _underlying: IERC20(FRXUSD),
        _name: "Staked Frax USD",
        _symbol: "sfrxUSD",
        _timelockAddress: Constants.Mainnet.FRAX_ERC20_OWNER
    });

    // Used for verification
    console.log("Constructor Arguments abi encoded: ");
    console.logBytes(abi.encode(IERC20(FRXUSD), "Staked Frax USD", "sfrxUSD", Constants.Mainnet.FRAX_ERC20_OWNER));
}

contract DeployStakedFrxUSD2 is BaseScript {
    function run() public broadcaster returns (StakedFrxUSD2 _stakedFrxUSD2) {
        // Deploy the implementation
        _stakedFrxUSD2 = deployStakedFrxUSD2();

        // Upgrade the proxy
        // {
        //     // Find the proxy admin
        //     // Should be 0xeA0a6EC8114a0Af6Cf74Ca0036Ab31d892Df13cB
        //     bytes32 adminSlot = vm.load(address(stakedFrxUSD2_pxy), ERC1967Utils.ADMIN_SLOT);
        //     pxyAdmin = ProxyAdmin(address(uint160(uint256(adminSlot))));
        //     console.log("Proxy Admin: ", address(pxyAdmin));

        //     // Upgrade the proxy
        //     startHoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        //     bytes memory data = abi.encodeCall(
        //         stakedFrxUSD2_impl.initialize,
        //         ("Staked Frax USD", "sfrxUSD", Constants.Mainnet.FRAX_ERC20_OWNER)
        //     );
        //     pxyAdmin.upgradeAndCall(stakedFrxUSD2_pxy, address(stakedFrxUSD2_impl), data);
        //     vm.stopPrank();
        // }
    }

    function runTest() external returns (StakedFrxUSD2) {
        return run();
    }
}
