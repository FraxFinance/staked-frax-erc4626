// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { StakedFrax } from "../contracts/StakedFrax.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../Constants.sol" as Constants;

function deployStakedFrax() returns (StakedFrax _stakedFrax) {
    uint256 TEN_PERCENT = 3_022_266_030; // per second rate compounded week each block (1.10^(365 * 86400 / 12) - 1) / 12 * 1e18

    _stakedFrax = new StakedFrax({
        _underlying: IERC20(Constants.Mainnet.FRAX_ERC20),
        _name: "Staked Frax",
        _symbol: "sFRAX",
        _rewardsCycleLength: 7 days,
        _maxDistributionPerSecondPerAsset: TEN_PERCENT,
        _timelockAddress: Constants.Mainnet.SFRAX_FXB_GOVERNANCE_ADDRESS
    });

    // Used for verification
    console.log("Constructor Arguments abi encoded: ");
    console.logBytes(
        abi.encode(
            IERC20(Constants.Mainnet.FRAX_ERC20),
            "Staked Frax",
            "sFRAX",
            7 days,
            TEN_PERCENT,
            Constants.Mainnet.TIMELOCK_ADDRESS
        )
    );
}

// NOTE: This contract deployed specifically to prevent known inflations attacks on share price in ERC4626
contract DeployAndDepositStakedFrax {
    function deployStakedFraxAndDeposit() external returns (address _stakedFraxAddress) {
        StakedFrax _stakedFrax = deployStakedFrax();
        _stakedFraxAddress = address(_stakedFrax);
        IERC20(Constants.Mainnet.FRAX_ERC20).approve(address(_stakedFrax), 1000e18);
        _stakedFrax.deposit(1000e18, msg.sender);
    }
}

// This is a free function that can be imported and used in tests or other scripts
function deployDeployAndDepositStakedFrax() returns (address _stakedFraxAddress) {
    DeployAndDepositStakedFrax _bundle = new DeployAndDepositStakedFrax();
    IERC20(Constants.Mainnet.FRAX_ERC20).transfer(address(_bundle), 1000e18);
    _stakedFraxAddress = _bundle.deployStakedFraxAndDeposit();
    console.log("Deployed StakedFrax at address: ", _stakedFraxAddress);
}

contract DeployStakedFrax is BaseScript {
    function run() public broadcaster {
        address _address = deployDeployAndDepositStakedFrax();
        console.log("Deployed deployDeployAndDepositStakedFrax at address: ", _address);
    }
}
