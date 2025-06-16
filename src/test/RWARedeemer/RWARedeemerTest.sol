// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { RWARedeemer } from "../../contracts/RWARedeemer.sol";

contract RWARedeemerTest is FraxTest {
    RWARedeemer redeemer;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 22_124_421);
    }

    function test_redeem_BUIDL() public {
        address RWA = 0x7712c34205737192402172409a8F7ccef8aA2AEc;
        address frxUSDCustodian = 0xE827ABf9F462Ac4f147753D86bc5f91E186E4E9c;
        address rwaUSDCRedeemer = 0x31D3F59Ad4aAC0eeE2247c65EBE8Bf6E9E470a53;
        address comptroler = 0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27;
        redeemer = new RWARedeemer(RWA, frxUSDCustodian, rwaUSDCRedeemer);
        whitelist(address(frxUSDCustodian));
        whitelist(address(redeemer));
        vm.startPrank(comptroler);
        IERC20(RWA).transfer(frxUSDCustodian, 100e6);
        redeemer.frxUSD().approve(address(redeemer), 100e18);
        uint256 usdcAmountOut = redeemer.redeem(100e18, 99.98e6);
        console.log(usdcAmountOut);
        vm.stopPrank();
    }

    function test_redeem_USTB() public {
        address RWA = 0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e;
        address frxUSDCustodian = 0x5fbAa3A3B489199338fbD85F7E3D444dc0504F33;
        address rwaUSDCRedeemer = 0x4c21B7577C8FE8b0B0669165ee7C8f67fa1454Cf;
        address comptroler = 0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27;
        redeemer = new RWARedeemer(RWA, frxUSDCustodian, rwaUSDCRedeemer);
        vm.startPrank(0x7747940aDBc7191f877a9B90596E0DA4f8deb2Fe);
        AllowList(0x02f1fA8B196d21c7b733EB2700B825611d8A38E5).setEntityIdForAddress(34, frxUSDCustodian);
        AllowList(0x02f1fA8B196d21c7b733EB2700B825611d8A38E5).setEntityIdForAddress(34, address(redeemer));
        vm.stopPrank();
        vm.startPrank(comptroler);
        IERC20(RWA).transfer(frxUSDCustodian, 100e6);
        redeemer.frxUSD().approve(address(redeemer), 100e18);
        uint256 usdcAmountOut = redeemer.redeem(100e18, 99.98e6);
        console.log(usdcAmountOut);
        vm.stopPrank();
    }

    function whitelist(address _wallet) public {
        IRegistryService registryService = IRegistryService(0x0Dac900f26DE70336f2320F7CcEDeE70fF6A1a5B);
        vm.startPrank(0x008075B22bEc05C7D0fb789e3420b76056D76cab);
        registryService.addWallet(_wallet, registryService.getInvestor(0xEd71aa0dA4fdBA512FfA398fcFf9db8C49A5Cf72));
        vm.stopPrank();
    }
}

interface AllowList {
    function setEntityIdForAddress(uint256 entityId, address addr) external;
}

interface IRegistryService {
    function addWallet(address _wallet, string memory _name) external;

    function getInvestor(address _address) external view returns (string memory);
}
