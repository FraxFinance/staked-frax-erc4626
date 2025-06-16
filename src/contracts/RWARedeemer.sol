// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.21;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// =========================== RWARedeemer ============================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FrxUSDCustodian } from "./FrxUSDCustodian.sol";
import { IRWAUSDCRedeemer } from "./interfaces/IRWAUSDCRedeemer.sol";

contract RWARedeemer {
    // Addresses
    IERC20 public constant frxUSD = IERC20(0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public immutable RWA;
    FrxUSDCustodian public immutable frxUSDCustodian;
    IRWAUSDCRedeemer public immutable rwaUSDCRedeemer;

    constructor(address _RWA, address _frxUSDCustodian, address _rwaUSDCRedeemer) {
        RWA = IERC20(_RWA);
        frxUSDCustodian = FrxUSDCustodian(_frxUSDCustodian);
        rwaUSDCRedeemer = IRWAUSDCRedeemer(_rwaUSDCRedeemer);
    }

    function redeem(uint256 amount, uint256 minAmountOut) external returns (uint256 amountUSDCOut) {
        frxUSD.transferFrom(msg.sender, address(this), amount);
        frxUSD.approve(address(frxUSDCustodian), amount);
        uint256 amountRWAOut = frxUSDCustodian.redeem(amount, address(this), address(this));
        RWA.approve(address(rwaUSDCRedeemer), amountRWAOut);
        rwaUSDCRedeemer.redeem(amountRWAOut);
        amountUSDCOut = USDC.balanceOf(address(this));
        require(amountUSDCOut >= minAmountOut, "RWARedeemer: INSUFFICIENT_OUTPUT_AMOUNT");
        USDC.transfer(msg.sender, amountUSDCOut);
    }
}
