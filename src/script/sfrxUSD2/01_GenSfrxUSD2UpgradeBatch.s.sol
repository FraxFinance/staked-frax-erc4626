// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { StakedFrxUSD2 } from "src/contracts/StakedFrxUSD2.sol";
import { Strings } from "@openzeppelin-4/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../Constants.sol" as Constants;

contract GenSfrxUSD2UpgradeBatch is BaseScript {
    string txBatchJson =
        '{"version":"1.0","chainId":"<CHAIN_ID>","createdAt":66666666666666,"meta":{"name":"01_GenSfrxUSD2UpgradeBatch","description":"","txBuilderVersion":"1.18.0","createdFromSafeAddress":"<SIGNING_SAFE_ADDRESS>","createdFromOwnerAddress":"","checksum":"<CHECKSUM>"},"transactions":[{}]}';
    string JSON_PATH = "src/script/sfrxUSD2/batches/01_GenSfrxUSD2UpgradeBatch.json";

    // ProxyAdmin
    ProxyAdmin pxyAdmin;

    // frxUSD
    IERC20 public frxUSDErc20 = IERC20(Constants.Mainnet.FRXUSD_ADDRESS);

    // sfrxUSD
    StakedFrxUSD2 public sfrxUSD2 = StakedFrxUSD2(Constants.Mainnet.SFRXUSD_PXY_ADDRESS);
    StakedFrxUSD2 public stakedFrxUSD2_impl = StakedFrxUSD2(Constants.Mainnet.SFRXUSD2_IMPL);
    address public stakedFrxUSD2Address = Constants.Mainnet.SFRXUSD_PXY_ADDRESS;
    ITransparentUpgradeableProxy public stakedFrxUSD2_pxy =
        ITransparentUpgradeableProxy(Constants.Mainnet.SFRXUSD_PXY_ADDRESS);

    // For sfrxUSD2 initialization
    uint256[2] ppsInfo;

    // Misc
    string _txJson;
    bytes _theCallData;
    bytes _theEncodedCall;

    function run() public broadcaster {
        // Start broadcasting
        console.log("Executing as", msg.sender);

        // Find the proxy admin
        // Should be 0xeA0a6EC8114a0Af6Cf74Ca0036Ab31d892Df13cB
        bytes32 adminSlot = vm.load(Constants.Mainnet.SFRXUSD_PXY_ADDRESS, ERC1967Utils.ADMIN_SLOT);
        pxyAdmin = ProxyAdmin(address(uint160(uint256(adminSlot))));
        console.log("Proxy Admin: ", address(pxyAdmin));

        // Create the json
        vm.writeJson(txBatchJson, JSON_PATH);

        // Set misc json variables
        vm.writeJson(Strings.toString(uint256(1)), JSON_PATH, ".chainId");
        vm.writeJson(Strings.toString(uint256(block.timestamp)), JSON_PATH, ".createdAt");
        vm.writeJson(Strings.toHexString(address(pxyAdmin)), JSON_PATH, ".meta.createdFromSafeAddress");

        // Initial pricePerShare and rate info
        ppsInfo[0] = sfrxUSD2.pricePerShare();
        ppsInfo[1] = stakedFrxUSD2_impl.calcPPSIPSForGivenAPY(1.05e18);

        // Print info
        console.log("======== Initial ========");
        console.log("PPS: ", ppsInfo[0]);
        console.log("Calculated PPSPS: ", ppsInfo[1]);
        console.log("totalAssets: ", sfrxUSD2.totalAssets());
        console.log("storedTotalAssets: ", sfrxUSD2.storedTotalAssets());
        console.log("totalSupply: ", sfrxUSD2.totalSupply());

        // Encode the initialization call
        _theEncodedCall = abi.encodeCall(
            stakedFrxUSD2_impl.initialize,
            ("Staked Frax USD", "sfrxUSD", Constants.Mainnet.FRAX_ERC20_OWNER, ppsInfo)
        );

        // Get the calldata
        _theCallData = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector,
            stakedFrxUSD2Address,
            address(stakedFrxUSD2_impl),
            _theEncodedCall
        );

        // Fill the tx json and write
        _txJson = generateTxJson(address(pxyAdmin), _theCallData);
        vm.writeJson(_txJson, JSON_PATH, ".transactions[0]");
    }

    function generateTxJson(address _to, bytes memory _data) public returns (string memory _txString) {
        _txString = "{";
        _txString = string.concat(_txString, '"to": "', Strings.toHexString(_to), '", ');
        _txString = string.concat(_txString, '"value": "0", ');
        _txString = string.concat(_txString, '"data": "', iToHex(_data, true), '", ');
        _txString = string.concat(_txString, '"contractMethod": null, ');
        _txString = string.concat(_txString, '"contractInputsValues": null');
        _txString = string.concat(_txString, "}");
    }

    function iToHex(bytes memory buffer, bool _addPrefix) public pure returns (string memory) {
        // Fixed buffer size for hexadecimal convertion
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        if (_addPrefix) return string(abi.encodePacked("0x", converted));
        else return string(abi.encodePacked(converted));
    }
}
