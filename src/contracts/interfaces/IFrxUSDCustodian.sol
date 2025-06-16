// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IFrxUSDCustodian {
    function previewDeposit(uint256 amount) external view returns (uint256);

    function deposit(uint256 amount, address receiver) external returns (uint256);
}
