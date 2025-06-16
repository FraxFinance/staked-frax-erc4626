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
// ======================= FraxNetDeposit =============================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IFrxUSDCustodian } from "./interfaces/IFrxUSDCustodian.sol";
import { IRemoteHop } from "./interfaces/IRemoteHop.sol";
import { FraxNetDepositFactory } from "./FraxNetDepositFactory.sol";

/**
 * @title FraxNetDeposit
 * @notice Facilitates deposits of USDC to mint frxUSD and send it to a target address
 * across different chains via LayerZero OFT (Omnichain Fungible Token) mechanism
 * @dev This contract serves as an interface between USDC deposits and cross-chain frxUSD transfers
 */
contract FraxNetDeposit {
    // ========== Token Addresses ==========

    /// @notice The frxUSD stablecoin token address
    IERC20 public constant frxUSD = IERC20(0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29);

    /// @notice The USDC stablecoin token address
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    /// @notice The LayerZero OFT (Omnichain Fungible Token) address for frxUSD
    address public constant oft = 0x566a6442A5A6e9895B9dCA97cC7879D632c6e4B0;

    /// @notice Address of the factory contract that deployed this contract
    /// @dev Used for access control in admin functions
    FraxNetDepositFactory public immutable factory;

    // ========== Cross-Chain Parameters ==========

    /// @notice The target chain's endpoint ID in the LayerZero network
    uint32 public targetEid;

    /// @notice The recipient address on the target chain (in bytes32 format)
    bytes32 public targetAddress;

    // ========== Custom Errors ==========

    /// @notice Thrown when a non-authorized address attempts a restricted operation
    error Forbidden();

    /// @notice Thrown when there are insufficient token funds for an operation
    error InsufficientBalance();

    /// @notice Thrown when a native token transfer fails
    error TransferFailed();

    /**
     * @notice Enables the contract to receive ETH
     * @dev Required for handling gas fees for cross-chain operations
     */
    receive() external payable {}

    /**
     * @notice Emitted when a USDC deposit is processed and frxUSD is sent
     * @param targetEid The LayerZero endpoint ID of the destination chain
     * @param targetAddress The recipient address on the target chain (in bytes32 format)
     * @param amount The amount of USDC processed
     * @param frxUSDOut The amount of frxUSD sent
     */
    event Processed(uint32 indexed targetEid, bytes32 indexed targetAddress, uint256 amount, uint256 frxUSDOut);

    /**
     * @notice Initializes the contract with the factory address
     * @dev The factory address is set to the address that deployed this contract
     */
    constructor() {
        factory = FraxNetDepositFactory(msg.sender);
    }

    /**
     * @notice Sets the target chain ID and recipient address
     * @dev Can only be called by the factory that deployed this contract
     * @param _targetEid The LayerZero endpoint ID of the destination chain
     * @param _targetAddress The recipient address on the target chain (in bytes32 format)
     */
    function initialize(uint32 _targetEid, bytes32 _targetAddress) external {
        if (msg.sender != address(factory)) revert Forbidden();
        targetEid = _targetEid;
        targetAddress = _targetAddress;
    }

    /**
     * @notice Processes USDC deposits, mints frxUSD, and sends it to the target address
     * @dev Requires USDC to be transferred to this contract
     * @param amount The amount of USDC to process
     */
    function process(uint256 amount) external payable {
        if (!factory.isOperator(msg.sender)) revert Forbidden();

        // Verify sufficient USDC balance
        if (USDC.balanceOf(address(this)) < amount) revert InsufficientBalance();

        // Get the custodian and remote hop contract from the factory
        (IFrxUSDCustodian frxUSDCustodian, IRemoteHop remoteHop) = factory.getCustodianAndHop();

        // Approve and deposit USDC to mint frxUSD
        USDC.approve(address(frxUSDCustodian), amount);
        uint256 frxUSDOut = frxUSDCustodian.deposit(amount, address(this));

        // Handle frxUSD transfer based on destination chain
        if (targetEid == 30_101) {
            // Ethereum mainnet
            // Direct transfer if target is on the same chain (Ethereum)
            frxUSD.transfer(address(uint160(uint256(targetAddress))), frxUSDOut);
        } else {
            // Cross-chain transfer for other chains using LayerZero
            frxUSD.approve(address(remoteHop), frxUSDOut);
            remoteHop.sendOFT{ value: msg.value }(oft, targetEid, targetAddress, frxUSDOut);
        }

        // Return unused ETH (for gas) back to the sender
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(msg.sender).call{ value: balance }("");
            if (!success) revert TransferFailed();
        }

        emit Processed(targetEid, targetAddress, amount, frxUSDOut);
    }

    /**
     * @notice Estimates the messaging fee for cross-chain transfer
     * @dev Uses the RemoteHop interface to get the fee estimate
     * @param amount The amount of USDC to be transferred
     * @return The estimated messaging fee for the transfer
     */
    function quote(uint256 amount) external view returns (IRemoteHop.MessagingFee memory) {
        (IFrxUSDCustodian frxUSDCustodian, IRemoteHop remoteHop) = factory.getCustodianAndHop();
        uint256 frxUSDAmount = frxUSDCustodian.previewDeposit(amount);
        return remoteHop.quote(oft, targetEid, targetAddress, frxUSDAmount);
    }

    /**
     * @notice Admin function to recover any ERC20 tokens accidentally sent to this contract
     * @dev Can only be called by the factory (contract owner)
     * @param tokenAddress The address of the token to recover
     * @param tokenAmount The amount of tokens to recover
     * @param recipient The address to send the recovered tokens to
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount, address recipient) external {
        if (msg.sender != address(factory)) revert Forbidden();
        IERC20(tokenAddress).transfer(recipient, tokenAmount);
    }
}
