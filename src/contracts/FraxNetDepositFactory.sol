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
// ====================== FraxNetDepositFactory =======================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IFrxUSDCustodian } from "./interfaces/IFrxUSDCustodian.sol";
import { IRemoteHop } from "./interfaces/IRemoteHop.sol";
import { FraxNetDeposit } from "./FraxNetDeposit.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title FraxNetDepositFactory
 * @notice Factory contract to create FraxNetDeposit contracts using the minimal proxy pattern
 * @dev Uses EIP-1167 clones for gas-efficient deployment of multiple FraxNetDeposit instances
 */
contract FraxNetDepositFactory is Ownable2Step {
    /// @notice Reference to the FrxUSDCustodian contract that mints frxUSD
    IFrxUSDCustodian public frxUSDCustodian;

    /// @notice Interface for cross-chain communication
    IRemoteHop public remoteHop;

    /// @notice Array of all FraxNetDeposit contracts created by this factory
    /// @dev Used for tracking and enumeration of deployed instances
    FraxNetDeposit[] public fraxNetDepositContracts;

    /// @notice Mapping to check if a given address is a FraxNetDeposit contract
    /// @dev Used for quick lookups to verify contract type
    mapping(address => bool) public isFraxNetDeposit;

    /// @notice Mapping to check if a given address is an operator
    /// @dev Operators are allowed to call the process function in FraxNetDeposit
    mapping(address => bool) public operators;

    /// @notice Implementation contract that serves as the template for clones
    /// @dev Using the minimal proxy pattern to reduce deployment costs
    FraxNetDeposit public immutable implementation;

    /**
     * @notice Event emitted when a new FraxNetDeposit contract is created
     * @param newContract The address of the newly created FraxNetDeposit contract
     * @param targetEid The LayerZero endpoint ID of the destination chain
     * @param targetAddress The recipient address on the target chain (in bytes32 format)
     */
    event FraxNetDepositCreated(
        FraxNetDeposit indexed newContract,
        uint32 indexed targetEid,
        bytes32 indexed targetAddress
    );

    /**
     * @notice Event emitted when the FrxUSDCustodian contract is updated
     * @param frxUSDCustodian The new FrxUSDCustodian contract address
     */
    event FrxUSDCustodianSet(IFrxUSDCustodian indexed frxUSDCustodian);

    /**
     * @notice Event emitted when the RemoteHop contract is updated
     * @param remoteHop The new RemoteHop contract address
     */
    event RemoteHopSet(IRemoteHop indexed remoteHop);

    /**
     * @notice Event emitted when an operator is set or unset
     * @param operator The address of the operator
     * @param isOp True if the address is an operator, false otherwise
     */
    event OperatorSet(address indexed operator, bool isOp);

    /**
     * @notice Initializes the factory with required dependencies
     * @param _frxUSDCustodian The FrxUSDCustodian contract that handles frxUSD minting
     * @param _remoteHop The RemoteHop interface for cross-chain communication
     */
    constructor(IFrxUSDCustodian _frxUSDCustodian, IRemoteHop _remoteHop) Ownable(msg.sender) {
        frxUSDCustodian = _frxUSDCustodian;
        remoteHop = _remoteHop;

        // Deploy the implementation contract that will be cloned
        implementation = new FraxNetDeposit();
    }

    /**
     * @notice Creates a new FraxNetDeposit contract for a specific target chain and address
     * @dev Uses deterministic deployment to ensure consistency and predictability
     * @param _targetEid The LayerZero endpoint ID of the destination chain
     * @param _targetAddress The recipient address on the target chain (in bytes32 format)
     * @return newContract The newly created FraxNetDeposit contract
     */
    function createFraxNetDeposit(
        uint32 _targetEid,
        bytes32 _targetAddress
    ) external returns (FraxNetDeposit newContract) {
        // Clone the implementation contract using deterministic deployment
        // The salt is a hash of the target chain ID and address to ensure uniqueness
        newContract = FraxNetDeposit(
            payable(
                Clones.cloneDeterministic(
                    address(implementation),
                    keccak256(abi.encodePacked(_targetEid, _targetAddress))
                )
            )
        );

        // Initialize the clone with its configuration parameters
        newContract.initialize(_targetEid, _targetAddress);

        // Add the new contract to the list of FraxNetDeposit contracts
        fraxNetDepositContracts.push(newContract);
        isFraxNetDeposit[address(newContract)] = true;
        emit FraxNetDepositCreated(newContract, _targetEid, _targetAddress);
    }

    /**
     * @notice Predicts the address where a FraxNetDeposit contract would be deployed
     * @dev Useful for integration testing and verification before actual deployment
     * @param _targetEid The LayerZero endpoint ID of the destination chain
     * @param _targetAddress The recipient address on the target chain (in bytes32 format)
     * @return The address where the FraxNetDeposit contract would be deployed
     */
    function getDeploymentAddress(uint32 _targetEid, bytes32 _targetAddress) external view returns (address) {
        return
            Clones.predictDeterministicAddress(
                address(implementation),
                keccak256(abi.encodePacked(_targetEid, _targetAddress)),
                address(this)
            );
    }

    /**
     * @notice Returns the number of FraxNetDeposit contracts created by this factory
     * @return The length of the fraxNetDepositContracts array
     */
    function fraxNetDepositContractsLength() external view returns (uint256) {
        return fraxNetDepositContracts.length;
    }

    /**
     * @notice Admin function to recover ERC20 tokens stuck in any FraxNetDeposit contract
     * @dev Can only be called by the owner of the factory
     * @param tokenAddress The address of the token to recover
     * @param tokenAmount The amount of tokens to recover
     * @param fraxNetDepositContract The specific FraxNetDeposit contract to recover tokens from
     */
    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount,
        FraxNetDeposit fraxNetDepositContract,
        address recipient
    ) external onlyOwner {
        fraxNetDepositContract.recoverERC20(tokenAddress, tokenAmount, recipient);
    }

    /**
     * @notice Admin function to set a new FrxUSDCustodian contract
     * @dev Can only be called by the owner of the factory
     * @param _frxUSDCustodian The new FrxUSDCustodian contract address
     */
    function setFrxUSDCustodian(IFrxUSDCustodian _frxUSDCustodian) external onlyOwner {
        frxUSDCustodian = _frxUSDCustodian;
        emit FrxUSDCustodianSet(_frxUSDCustodian);
    }

    /**
     * @notice Admin function to set a new RemoteHop contract
     * @dev Can only be called by the owner of the factory
     * @param _remoteHop The new RemoteHop contract address
     */
    function setRemoteHop(IRemoteHop _remoteHop) external onlyOwner {
        remoteHop = _remoteHop;
        emit RemoteHopSet(_remoteHop);
    }

    function setOperator(address operator, bool isOp) external onlyOwner {
        operators[operator] = isOp;
        emit OperatorSet(operator, isOp);
    }

    /**
     * @notice Returns the addresses of the FrxUSDCustodian and RemoteHop contracts
     * @return frxUSDCustodian_ The address of the FrxUSDCustodian contract
     * @return remoteHop_ The address of the RemoteHop contract
     */
    function getCustodianAndHop() external view returns (IFrxUSDCustodian frxUSDCustodian_, IRemoteHop remoteHop_) {
        frxUSDCustodian_ = frxUSDCustodian;
        remoteHop_ = remoteHop;
    }

    /**
     * @notice Verifies if the given address is an operator
     * @dev Operators are allowed to call the process function in FraxNetDeposit
     * @param operator The address to check
     * @return True if the address is an operator, false otherwise
     */
    function isOperator(address operator) external view returns (bool) {
        return owner() == operator || operators[operator];
    }
}
