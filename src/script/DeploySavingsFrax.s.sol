// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { SavingsFrax } from "../contracts/SavingsFrax.sol";
import { ERC20 } from "solmate/mixins/ERC4626.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../Constants.sol" as Constants;

function deploySavingsFrax() returns (SavingsFrax _savingsFrax) {
    uint256 TEN_PERCENT = 3_033_347_948; // per second rate compounded weekly (1.10^(1/52) - 1) * 1e18 / (7 * 86400)

    _savingsFrax = new SavingsFrax({
        _underlying: IERC20(Constants.Mainnet.FRAX_ERC20),
        _name: "Savings Frax",
        _symbol: "sFRAX",
        _rewardsCycleLength: 7 days,
        _maxDistributionPerSecondPerAsset: 2 * TEN_PERCENT,
        _timelockAddress: Constants.Mainnet.TIMELOCK_ADDRESS
    });
}

// NOTE: This contract deployed specifically to prevent known inflations attacks on share price in ERC4626
contract DeployAndDepositSavingsFrax {
    function deploySavingsFraxAndDeposit() external returns (address _savingsFraxAddress) {
        SavingsFrax _savingsFrax = deploySavingsFrax();
        _savingsFraxAddress = address(_savingsFrax);
        IERC20(Constants.Mainnet.FRAX_ERC20).approve(address(_savingsFrax), 1000e18);
        _savingsFrax.deposit(1000e18, msg.sender);
    }
}

// This is a free function that can be imported and used in tests or other scripts
function deployDeployAndDepositSavingsFrax() returns (address _savingsFraxAddress) {
    DeployAndDepositSavingsFrax _bundle = new DeployAndDepositSavingsFrax();
    IERC20(Constants.Mainnet.FRAX_ERC20).transfer(address(_bundle), 1000e18);
    _savingsFraxAddress = _bundle.deploySavingsFraxAndDeposit();
}

// Run this with source .env && forge script --broadcast --rpc-url $MAINNET_URL DeployCounter.s.sol
contract DeploySavingsFrax is BaseScript {
    function run() public broadcaster {
        address _address = deployDeployAndDepositSavingsFrax();
        console.log("Deployed Counter at address: ", _address);
    }
}
